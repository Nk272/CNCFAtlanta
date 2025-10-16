from fastapi import FastAPI
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import torch, time

app = FastAPI()
model = tokenizer = None
model_ready = False
startup_time = None

@app.on_event("startup")
def load_model():
    global model, tokenizer, model_ready, startup_time
    print("Initializing GPU + loading model...")
    start = time.time()
    model_name = "distilbert-base-uncased-finetuned-sst-2-english"
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(model_name).to("cuda")
    model.eval()
    try:
        torch.backends.cuda.matmul.allow_tf32 = True
    except Exception:
        pass
    _ = tokenizer("warmup", return_tensors="pt")
    with torch.inference_mode():
        inputs = tokenizer("warmup", return_tensors="pt").to("cuda")
        with torch.autocast("cuda", dtype=torch.float16):
            _ = model(**inputs)
        torch.cuda.synchronize()
    startup_time = time.time() - start
    model_ready = True
    print(f"Model loaded in {startup_time:.2f}s")

@app.get("/health")
def health():
    if model_ready:
        return {"status": "ready", "startup_time": f"{startup_time:.2f}s"}
    return {"status": "loading"}, 503

@app.get("/predict")
def predict(text: str):
    inference_start = time.time()
    inputs = tokenizer(text, return_tensors="pt").to("cuda")
    with torch.inference_mode():
        with torch.autocast("cuda", dtype=torch.float16):
            outputs = model(**inputs)
    label = torch.argmax(outputs.logits).item()
    inference_time = time.time() - inference_start
    
    sentiment = "POSITIVE" if label == 1 else "NEGATIVE"
    return {
        "text": text,
        "sentiment": sentiment,
        "label": label,
        "inference_time_ms": f"{inference_time*1000:.2f}",
        "model_startup_time": f"{startup_time:.2f}s"
    }
