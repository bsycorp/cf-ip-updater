FROM bsycorp/debian-build-tools:latest

RUN mkdir /app
COPY . /app
WORKDIR /app

RUN /usr/bin/terraform init
RUN chmod +x /app/run.sh

CMD ["/app/run.sh"]
