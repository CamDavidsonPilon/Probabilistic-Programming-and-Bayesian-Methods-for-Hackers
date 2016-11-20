FROM jupyter/datascience-notebook

ADD . /home/jovyan/work

USER $NB_USER

RUN pip2 install -r /home/$NB_USER/work/requirements.txt

