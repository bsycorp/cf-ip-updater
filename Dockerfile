FROM bsycorp/debian-build-tools:latest

RUN mkdir /app
COPY . /app
WORKDIR /app

RUN /usr/bin/terraform init

CMD ["/app/run.sh"]