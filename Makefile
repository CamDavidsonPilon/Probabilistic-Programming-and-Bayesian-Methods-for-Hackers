build:
	docker build -t bayesian .
jn:
	docker run --name bayesian -d -p 8888:8888 -v $(shell pwd):/home/jovyan/work bayesian
stop:
	docker stop bayesian
	docker rm bayesian
