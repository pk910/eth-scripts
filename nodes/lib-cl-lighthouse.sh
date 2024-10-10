#!/bin/bash

# general options
node_name="${node_name:-node1}" # docker container prefix
node_user="${node_user:-$node_name}" # run as username
node_uid="$(id -u $node_user)"

# images
bn_image="${bn_image:-sigp/lighthouse:latest}"
vc_image="${vc_image:-sigp/lighthouse:latest}"

# datadirs
base_dir="${base_dir:-/data/$node_name}"
config_dir="${config_dir:-$base_dir/config}"
bn_datadir="${bn_datadir:-$base_dir/beacon}"
vc_datadir="${vc_datadir:-$base_dir/validator}"
jwtsecret_file="${jwtsecret_file:-$base_dir/jwtsecret}"

# extra args
bn_extra_args="${bn_extra_args:-}"
vc_extra_args="${vc_extra_args:-}"

# ports
el_engine_port="${el_engine_port:-8551}"
bn_p2p_port="${bn_p2p_port:-9000}"
bn_rpc_port="${bn_rpc_port:-5052}"
bn_metrics_port="${bn_metrics_port:-5054}"
vc_metrics_port="${vc_metrics_port:-5055}"
port_offset="${port_offset:-0}"  # increase all ports by this offset

# misc
fee_recipient="${fee_recipient:-0x14627ea0e2B27b817DbfF94c3dA383bB73F8C30b}"
graffiti="${graffiti:-pk910}"


if [ -z "$extip" ]; then
  extip=$(curl -s http://ipinfo.io/ip)
fi
if [ -z "$node_uid" ]; then
  useradd -m $node_user
  node_uid="$(id -u $node_user)"
fi

# start / stop scripts

start_bn() {
  ensure_datadir $bn_datadir
  p2p_port=$(expr $bn_p2p_port + $port_offset)
  rpc_port=$(expr $bn_rpc_port + $port_offset)
  engine_port=$(expr $el_engine_port + $port_offset)
  metrics_port=$(expr $bn_metrics_port + $port_offset)
  ensure_jwtsecret

  bootnodes=""
  if [ -f $config_dir/bootstrap_nodes.txt ]; then
    bootnodes_arr=()
    while IFS= read -r line; do
      bootnodes_arr+=($line)
    done < $config_dir/bootstrap_nodes.txt
    bootnodes="--boot-nodes=$(join_by , "${bootnodes_arr[@]}")"
  fi

  extra_args=()
  if [ ! -z "$bn_extra_args" ]; then
    extra_args+=("${bn_extra_args[@]}")
  fi
  extra_args+=("--testnet-dir=/config")
  if [ ! -z "$bootnodes" ]; then
    extra_args+=("$bootnodes")
  fi
  
  # lighthouse bn
  docker run -d --restart unless-stopped --name=$node_name-bn \
    --pull always \
    -u $node_uid \
    -v $jwtsecret_file:/execution-auth.jwt:ro \
    -v $bn_datadir:/data \
    -v $config_dir:/config \
    -p $p2p_port:$p2p_port \
    -p $p2p_port:$p2p_port/udp \
    -p $rpc_port:$rpc_port \
    -p $metrics_port:$metrics_port \
    -it $bn_image \
    lighthouse beacon_node \
    --datadir=/data \
    --disable-upnp --disable-enr-auto-update --enr-address=$extip \
    --port=$p2p_port --discovery-port=$p2p_port --enr-tcp-port=$p2p_port --enr-udp-port=$p2p_port \
    --listen-address=0.0.0.0 \
    --http --http-address=0.0.0.0 --http-port=$rpc_port \
    --execution-endpoint=http://172.17.0.1:$engine_port --execution-jwt=/execution-auth.jwt \
    --metrics --metrics-allow-origin=* --metrics-address=0.0.0.0 --metrics-port=$metrics_port \
    "${extra_args[@]}"
}

start_vc() {
  ensure_datadir $vc_datadir
  rpc_port=$(expr $bn_rpc_port + $port_offset)
  metrics_port=$(expr $vc_metrics_port + $port_offset)

  extra_args=()
  if [ ! -z "$vc_extra_args" ]; then
    extra_args+=("${vc_extra_args[@]}")
  fi
  extra_args+=("--testnet-dir=/config")

  # lighthouse vc
  docker run -d --restart unless-stopped --name=$node_name-vc \
    --pull always \
    -u $node_uid \
    -v $vc_datadir:/data \
    -v $config_dir:/config \
    -p $metrics_port:$metrics_port \
    -it $vc_image \
    lighthouse validator_client \
    --validators-dir=/data/keys \
    --secrets-dir=/data/secrets \
    --init-slashing-protection \
    --beacon-nodes=http://172.17.0.1:$rpc_port \
    --metrics --metrics-allow-origin=* --metrics-address=0.0.0.0 --metrics-port=$metrics_port \
    --graffiti $graffiti --suggested-fee-recipient $fee_recipient "${extra_args[@]}"
}

copy_vc_keys() {
  ensure_datadir $vc_datadir
  keystores=$1
  if [ -f $vc_datadir/keys ]; then
    rm -rf $vc_datadir/keys
  fi
  if [ -f $vc_datadir/secrets ]; then
    rm -rf $vc_datadir/secrets
  fi

  cp $keystores/keys -r $vc_datadir/keys
  cp $keystores/secrets -r $vc_datadir/secrets
  chown -R $node_user $vc_datadir/keys $vc_datadir/secrets
}

stop_bn() {
  docker rm -f $node_name-bn
}

stop_vc() {
  docker rm -f $node_name-vc
}

if ! [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  
fi
