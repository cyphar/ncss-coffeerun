FROM python:3.12-bookworm

WORKDIR /usr/src/coffeebot

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN groupadd giversofcoffee -g 5000 && \
    useradd coffeesius -N -u 5000 -g giversofcoffee -b/bin/false
USER coffeesius

COPY . .
CMD [ "python", "./run.py" ]
VOLUME [ "/srv/data" ]
