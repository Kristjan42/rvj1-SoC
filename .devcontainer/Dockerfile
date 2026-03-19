FROM hpretl/iic-osic-tools:2025.12

RUN pip install --upgrade pip 
RUN pip install "cython<3.0.0" wheel 
RUN pip install "PyYAML==5.2" --no-build-isolation 
RUN pip install cocotb==2.0.0 
RUN pip install git+https://github.com/jurevreca12/forastero.git@09c1817 
RUN pip install git+https://github.com/jurevreca12/riscv-python-model@24daba0 
RUN pip uninstall -y riscv-config 
RUN pip install git+https://github.com/riscv-software-src/riscv-config@54171f2
RUN pip install git+https://github.com/riscv-software-src/riscof@aa146d4 
RUN pip uninstall -y riscv-isac 
RUN pip install git+https://github.com/riscv-software-src/riscv-isac@777d2b4
RUN pip install git+https://github.com/VyperCore/forastero-io.git
RUN pip install multimethod
RUN pip3 install --upgrade --user fusesoc
Run export PYGPI_PYTHON_BIN=$(cocotb-config --python-bin)

USER 0:0
RUN curl -L https://github.com/sifive/elf2hex/archive/refs/tags/v20.08.00.00.tar.gz -o elf2hex.tar.gz && \
    tar -xvzpf elf2hex.tar.gz && \
    rm elf2hex.tar.gz && \
    cd elf2hex-20.08.00.00 && \
    ./configure --target=riscv32-unknown-elf && \
    make && \
    make install

ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME

    
WORKDIR /foss/designs/rvj1-SoC