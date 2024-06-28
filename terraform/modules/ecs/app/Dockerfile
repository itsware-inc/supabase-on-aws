FROM python:3.8-slim-buster

COPY ./requirements.txt /app/requirements.txt

RUN apt-get -y update
RUN apt-get -y install curl

WORKDIR /app

RUN pip3 install -r requirements.txt

COPY . /app

EXPOSE 8081

ENTRYPOINT [ "python3" ]

CMD ["app.py"]