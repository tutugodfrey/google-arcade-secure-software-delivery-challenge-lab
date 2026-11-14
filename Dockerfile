FROM python:3.12-slim

# System
RUN apt update && apt install python3-pip -y

# App
WORKDIR /app
COPY . ./

# Dependencies
RUN pip3 install Flask==3.0.3  
RUN pip3 install gunicorn==23.0.0  
RUN pip3 install Werkzeug==3.0.4

# Run
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 main:app
