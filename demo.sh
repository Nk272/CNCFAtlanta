#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

HOST="gpu-coldstart.default.svc.cluster.local"
URL="http://localhost:8080/predict?text=I%20love%20this%20amazing%20demo"

# helpers for timing and json 
ToEpoch() { date -d "$1" +%s.%N; } 
GetNewestPod() { kubectl get pods -l app=gpu-coldstart -o json | jq -r '.items | max_by(.metadata.creationTimestamp) | .metadata.name'; } 
SafeNum() { test -n "$1" && echo "$1" || echo "0"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   GPU Cold Start vs Warm Start Test   ${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Step 1: Scaling deployment to 0 replicas...${NC}"
kubectl scale deployment gpu-coldstart --replicas=0
sleep 3

echo -e "${GREEN}Current pod count:${NC}"
kubectl get pods -l app=gpu-coldstart
echo ""

read -p "Press Enter to test COLD START (pod scaled from 0)..."

echo -e "\n${RED} COLD START TEST${NC}"
echo -e "Timing complete cold start (pod creation + GPU init + model load + inference)...\n"
START=$(date +%s.%N)
RESPONSE=$(curl -s -H "Host: $HOST" "$URL" 2>&1)
HTTP_CODE=$?
END=$(date +%s.%N)

# breakdown (best-effort from pod timestamps)
newPod=$(GetNewestPod || true)
if [ -n "$newPod" ]; then 
    createdTs=$(kubectl get pod "$newPod" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true)
    startedTs=$(kubectl get pod "$newPod" -o json | jq -r '.status.containerStatuses[0].state.running.startedAt // empty' 2>/dev/null || true)
    readyTs=$(kubectl get pod "$newPod" -o json | jq -r '.status.conditions[] | select(.type=="Ready") | .lastTransitionTime' 2>/dev/null || true)
    
    createdS=$(ToEpoch "$(SafeNum "$createdTs")" 2>/dev/null || echo 0)
    startedS=$(ToEpoch "$(SafeNum "$startedTs")" 2>/dev/null || echo 0)
    readyS=$(ToEpoch "$(SafeNum "$readyTs")" 2>/dev/null || echo 0) 
    
    reqToCreate=$(echo "$createdS - $START" | bc 2>/dev/null)
    createToStart=$(echo "$startedS - $createdS" | bc 2>/dev/null)
    startToReady=$(echo "$readyS - $startedS" | bc 2>/dev/null)
    
    readyToResp=$(echo "$END - $readyS" | bc 2>/dev/null)
    
    echo -e "${YELLOW}Cold Start Breakdown (approx):${NC}"
    echo "- Request -> PodCreated: ${reqToCreate}s"
    echo "- PodCreated -> ContainerStarted: ${createToStart}s"
    echo "- ContainerStarted -> Ready: ${startToReady}s"
    echo "- Ready -> FirstResponse: ${readyToResp}s"
    echo "" 
fi

TOTAL_TIME=$(echo "$END - $START" | bc)

echo -e "${GREEN}Response:${NC}"
if echo "$RESPONSE" | jq . > /dev/null 2>&1; then
    echo "$RESPONSE" | jq .
else
    echo "$RESPONSE"
    echo -e "${RED}Warning: Response is not valid JSON${NC}"
fi

echo -e "\n${RED}Cold Start Total Time: ${TOTAL_TIME}s${NC}"
echo -e "Curl exit code: $HTTP_CODE"
echo ""

echo -e "${GREEN}Waiting for pod to be ready...${NC}"
sleep 2
kubectl get pods -l app=gpu-coldstart
echo ""

read -p "Press Enter to test WARM START (pod already running)..."

echo -e "\n${GREEN}WARM START TEST${NC}"
echo -e "Timing warm request (inference only)...\n"

START=$(date +%s.%N)
RESPONSE=$(curl -s -H "Host: $HOST" "$URL" 2>&1)
HTTP_CODE=$?
END=$(date +%s.%N)

TOTAL_TIME=$(echo "$END - $START" | bc)

echo -e "${GREEN}Response:${NC}"
if echo "$RESPONSE" | jq . > /dev/null 2>&1; then
    echo "$RESPONSE" | jq .
else
    echo "$RESPONSE"
    echo -e "${RED}Warning: Response is not valid JSON${NC}"
fi

echo -e "\n${GREEN}Warm Start Total Time: ${TOTAL_TIME}s${NC}"
echo -e "Curl exit code: $HTTP_CODE"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           Test Complete!               ${NC}"
echo -e "${BLUE}========================================${NC}"

