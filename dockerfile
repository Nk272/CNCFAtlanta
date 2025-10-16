FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TRANSFORMERS_CACHE=/models/hf \
    HF_HOME=/models/hf \
    TOKENIZERS_PARALLELISM=false \
    HF_HUB_DISABLE_TELEMETRY=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Pre-download model and tokenizer into the image layer cache
RUN python -c "from transformers import AutoModelForSequenceClassification, AutoTokenizer; m='distilbert-base-uncased-finetuned-sst-2-english'; AutoTokenizer.from_pretrained(m); AutoModelForSequenceClassification.from_pretrained(m)" \
    && true

COPY main.py /app/main.py

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
