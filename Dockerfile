FROM mtmiller/octave:4.4

WORKDIR /app

COPY . /app

RUN ["octave-cli", "--eval", "pkg install -forge io statistics"]

CMD ["/bin/bash"]
