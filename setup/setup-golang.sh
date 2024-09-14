#!/bin/sh

get_github_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

mkdir -p /opt/golang
cd /opt/golang

golang_release=$(wget -qO- https://golang.org/dl/ | grep -oP '\/go([0-9\.]+)\.linux-amd64\.tar\.gz' | head -n 1 | grep -oP 'go[0-9\.]+' | grep -oP '[0-9\.]+' | head -c -2 )
if [ ! -z "$golang_release" ] && [ ! -d "$golang_release" ]; then
  wget "https://golang.org/dl/go${golang_release}.linux-amd64.tar.gz"

  if [ ! -f "go${golang_release}.linux-amd64.tar.gz" ]; then
    echo "unexpected error: go${golang_release}.linux-amd64.tar.gz not found"
    exit
  fi

  mkdir $golang_release
  cd $golang_release
  rm -rf /usr/local/go
  tar xfz ../go${golang_release}.linux-amd64.tar.gz -C /usr/local

  cd ..
fi

if [ ! -f /etc/profile.d/golang.sh ]; then
  echo "export PATH=\$PATH:/usr/local/go/bin" > /etc/profile.d/golang.sh
  chmod +x /etc/profile.d/golang.sh
fi
