FROM alpine

# RUN apt-get update \
#    && apt-get install -y --no-install-recommends \
#    git ca-certificates build-essential \
#    cmake libssl-dev wget sudo

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
#    git ca-certificates build-essential \
#    cmake libssl-dev wget sudo


#RUN useradd -m burstminer && \
#    echo "burstminer:burstminer" | chpasswd

#RUN git clone https://github.com/Creepsky/creepMiner.git

# install-poco needs root
#RUN cd creepMiner && sh ./install-poco.sh

#RUN chown -R burstminer /creepMiner
#USER burstminer

#WORKDIR /creepMiner
#RUN cmake CMakeLists.txt -DNO_GPU=ON -DCMAKE_BUILD_TYPE=RELEASE \
#    && make -j 4

#COPY --chown=burstminer mining.conf /creepMiner
 
# Only works when run from the bin dir
#WORKDIR bin
#ENTRYPOINT ["./creepMiner"]
ENTRYPOINT ["sleep"]
#CMD ["-c", "../mining.conf"]
CMD ["60"]
