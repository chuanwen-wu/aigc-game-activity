FROM python:3.10.12
WORKDIR /app

RUN pip install --upgrade pip
RUN python -m pip install -U Image
RUN python -m pip install -U requests
RUN python -m pip install -U boto3


COPY eks_run.py /app/
COPY inference.py /app/
COPY main.py /app/

ENTRYPOINT ["python", "-u", "main.py"]