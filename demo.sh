#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

HOST="gpu-coldstart.default.svc.cluster.local"
URL="http://localhost:8080/predict?text=I%20love%20this%20amazing%20demo"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   GPU Cold Start vs Warm Start Demo   ${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Step 1: Scaling deployment to 0 replicas...${NC}"
kubectl scale deployment gpu-coldstart --replicas=0
sleep 3

echo -e "${GREEN}Current pod count:${NC}"
kubectl get pods -l app=gpu-coldstart
echo ""

read -p "Press Enter to test COLD START (pod scaled from 0)..."

echo -e "\n${RED}🧊 COLD START TEST${NC}"
echo -e "Timing complete cold start (pod creation + GPU init + model load + inference)...\n"

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

echo -e "\n${RED}Cold Start Total Time: ${TOTAL_TIME}s${NC}"
echo -e "Curl exit code: $HTTP_CODE"
echo ""

echo -e "${GREEN}Waiting for pod to be ready...${NC}"
sleep 2
kubectl get pods -l app=gpu-coldstart
echo ""

read -p "Press Enter to test WARM START (pod already running)..."

echo -e "\n${GREEN}🔥 WARM START TEST${NC}"
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
echo -e "${BLUE}           Demo Complete!               ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${YELLOW}Key Observations:${NC}"
echo -e "1. Cold start includes: pod scheduling, container start, GPU init, model loading"
echo -e "2. Warm start is just inference time (milliseconds vs seconds)"
echo -e "3. KEDA HTTP Add-on handles queuing during cold start"
echo ""

