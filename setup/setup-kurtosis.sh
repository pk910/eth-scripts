#!/bin/sh

if ! [ -f /etc/apt/sources.list.d/kurtosis.list ]; then
  echo "deb [trusted=yes] https://apt.fury.io/kurtosis-tech/ /" | tee /etc/apt/sources.list.d/kurtosis.list > /dev/null
fi

apt-get update
apt-get install -y kurtosis-cli

echo ""
echo "Kurtosis setup complete!"
echo ""
