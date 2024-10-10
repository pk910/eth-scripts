#!/bin/bash

join_by() {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

load_github_config() {
  if [ -f $config_dir/genesis.json ]; then
    return
  fi

  if [ ! -f $config_dir ]; then
    mkdir -p $config_dir
  fi

  tempdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'devnet')
  if [ -z "$(which git)" ]; then
    apt-get install -y git
  fi

  cd $tempdir
  git clone $1 .
  cp -r ./${2:-.}/* $config_dir
  cd ~
  rm -rf $tempdir
}

ensure_jwtsecret() {
  if ! [ -f $jwtsecret_file ]; then
    jwtsecret_path=$(dirname $jwtsecret_file)
    if ! [ -f $jwtsecret_path ]; then
      mkdir -p $jwtsecret_path
    fi
    echo -n 0x$(openssl rand -hex 32 | tr -d "\n") > $jwtsecret_file
    chown $node_user $jwtsecret_file
  fi
}

ensure_datadir() {
  if ! [ -f $1 ]; then
    mkdir -p $1
    chown $node_user $1
  fi
}

reset_vc_keys() {
  count="$1"
  mnemonic="${@:2}"
  if [ -z "$count" ]; then
    echo "key-count argument missing. run with ./node.sh reset-vc-keys <key-count> <mnemonic>"
    exit 1
  fi
  if [ -z "$mnemonic" ]; then
    echo "mnemonic argument missing. run with ./node.sh reset-vc-keys <key-count> <mnemonic>"
    exit 1
  fi

  tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'keys')
  docker run --rm -v $tmpdir:/data -it protolambda/eth2-val-tools:latest keystores --out-loc /data/keystores --source-mnemonic "$mnemonic" --source-min 0 --source-max $count
  copy_vc_keys $tmpdir/keystores
  rm -rf $tmpdir
}

main_script() {
  case "$1" in
   start-el) start_el ;;
   stop-el) stop_el ;;
   init-el) init_el ;;
   start-bn) start_bn ;;
   stop-bn) stop_bn ;;
   start-vc) start_vc ;;
   stop-vc) stop_vc ;;
   reset-vc-keys) reset_vc_keys $2 "${@:3}" ;;
   *)
     echo "Usage $0 {start-el|stop-el|start-bn|stop-bn|start-vc|stop-vc|reset-vc-keys}"
    ;;
  esac
}
