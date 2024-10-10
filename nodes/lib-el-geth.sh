#!/bin/bash

# images
el_image="${el_image:-ethereum/client-go:stable}"

# datadirs
base_dir="${base_dir:-/data/$node_name}"
config_dir="${config_dir:-$base_dir/config}"
el_datadir="${el_datadir:-$base_dir/execution}"
jwtsecret_file="${jwtsecret_file:-$base_dir/jwtsecret}"

# extra args
el_extra_args="${el_extra_args:-}"

# ports
el_p2p_port="${el_p2p_port:-30303}"
el_rpc_port="${el_rpc_port:-8545}"
el_engine_port="${el_engine_port:-8551}"
el_metrics_port="${el_metrics_port:-9001}"
port_offset="${port_offset:-0}"  # increase all ports by this offset


if [ -z "$extip" ]; then
  extip=$(curl -s http://ipinfo.io/ip)
fi
if [ -z "$node_uid" ]; then
  useradd -m $node_user
  node_uid="$(id -u $node_user)"
fi

# start / stop scripts

start_el() {
  ensure_datadir $el_datadir
  p2p_port=$(expr $el_p2p_port + $port_offset)
  rpc_port=$(expr $el_rpc_port + $port_offset)
  engine_port=$(expr $el_engine_port + $port_offset)
  metrics_port=$(expr $el_metrics_port + $port_offset)
  ensure_jwtsecret

  bootnodes=""
  if [ -f $config_dir/enodes.txt ]; then
    bootnodes_arr=()
    while IFS= read -r line; do
      bootnodes_arr+=($line)
    done < $config_dir/enodes.txt
    bootnodes="--bootnodes=$(join_by , "${bootnodes_arr[@]}")"
  fi

  # geth
  extra_args=()
  if [ ! -z "$el_extra_args" ]; then
    extra_args+=("${el_extra_args[@]}")
  fi
  if [ ! -z "$bootnodes" ]; then
    extra_args+=("$bootnodes")
  fi

  docker run -d --restart unless-stopped --name=$node_name-el \
    --pull always \
    -u $node_uid \
    -v $jwtsecret_file:/execution-auth.jwt:ro \
    -v $el_datadir:/data \
    -p $p2p_port:$p2p_port \
    -p $p2p_port:$p2p_port/udp \
    -p $rpc_port:$rpc_port \
    -p $engine_port:$engine_port \
    -p $metrics_port:$metrics_port \
    -it $el_image \
    --datadir=/data --port=$p2p_port \
    --http --http.addr=0.0.0.0 --http.port=$rpc_port \
    --http.vhosts=* --http.api=eth,net,web3,txpool,personal,debug \
    --authrpc.addr=0.0.0.0 --authrpc.port=$engine_port --authrpc.vhosts=* \
    --authrpc.jwtsecret=/execution-auth.jwt \
    --nat=extip:$extip \
    --metrics --metrics.addr=0.0.0.0 --metrics.port=$metrics_port \
    "${extra_args[@]}"
}

init_el() {
  ensure_datadir $el_datadir
  docker run --rm --name=$node_name-el-init \
    --pull always \
    -u $node_uid \
    -v $el_datadir:/data \
    -v $config_dir:/config \
    $el_image \
    init \
    --datadir=/data \
    /config/genesis.json
}

stop_el() {
  docker rm -f $node_name-el
}
