FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime
WORKDIR /app
COPY . .
RUN pip install fastapi uvicorn transformers
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
