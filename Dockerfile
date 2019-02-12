FROM centos:7

RUN yum install -y epel-release && \
    yum install -y gcc rpm-build rpm-devel rpmlint make python bash coreutils diffutils patch rpmdevtools git which createrepo

WORKDIR /src

# install some packaging tools
RUN git clone https://git.centos.org/git/centos-git-common.git

ENV PATH=${PATH}:/src/centos-git-common

# clone docker sources, get deps
RUN git clone https://git.centos.org/r/rpms/docker.git && \
    cd docker && \
    git checkout c7-extras && \
    get_sources.sh && \
    yum-builddep -y SPECS/docker.spec


# build docker
RUN cd docker && \
    rpmbuild --define "%_topdir `pwd`" -ba SPECS/docker.spec

# copy rpms and create metadata
RUN mkdir -p _output && \
    find ./docker/SRPMS/ ./docker/RPMS/ -name '*.rpm' | xargs -i cp {} ./_output/ && \
    createrepo ./_output/
