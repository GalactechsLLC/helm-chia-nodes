#!/usr/bin/env bash

# shellcheck disable=SC2154
if [[ -n "${TZ}" ]]; then
  echo "Setting timezone to ${TZ}"
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone
fi

cd /chia-blockchain || exit 1

# shellcheck disable=SC1091
. ./activate

# shellcheck disable=SC2086
chia ${chia_args} init --fix-ssl-permissions

if [[ -n ${ca} ]]; then
  # shellcheck disable=SC2086
  chia ${chia_args} init -c "${ca}"
fi

if [[ ${testnet} == 'true' ]]; then
  echo "configure testnet"
  chia configure --testnet true
  sed -i "s/selected_network: testnet10/selected_network: ${network}/g" "$CHIA_ROOT/config/config.yaml"
  sed -i "s/selected_network: testnet11/selected_network: ${network}/g" "$CHIA_ROOT/config/config.yaml"
  sed -i "s/testnet10.chia.net/${network}.chia.net/g" "$CHIA_ROOT/config/config.yaml"
  sed -i "s/testnet11.chia.net/${network}.chia.net/g" "$CHIA_ROOT/config/config.yaml"
fi

chia configure --upnp "${upnp}"

if [[ -n "${log_level}" ]]; then
  chia configure --log-level "${log_level}"
fi

if [[ -n ${crawler_db_path} ]]; then
  chia configure --crawler-db-path "${crawler_db_path}"
fi

if [[ -n "${peer_count}" ]]; then
  chia configure --set-peer-count "${peer_count}"
fi

if [[ -n "${outbound_peer_count}" ]]; then
  chia configure --set_outbound-peer-count "${outbound_peer_count}"
fi

if [[ -n ${crawler_db_path} ]]; then
  chia configure --crawler-db-path "${crawler_db_path}"
fi

if [[ -n ${crawler_minimum_version_count} ]]; then
  chia configure --crawler-minimum-version-count "${crawler_minimum_version_count}"
fi

if [[ ${use_checkpoint} == 'true' ]]; then
  if [[ ${testnet} == 'true' ]]; then
    file_size=$( (du -k "${CHIA_ROOT}/db/blockchain_v2_testnet11.sqlite" 2>/dev/null || echo 0) | cut -f 1)
    echo "Found DB of size ${file_size}k"
    if [[ $file_size -le 1048576 ]]; then
      cd "${CHIA_ROOT}/db/" || exit
      echo "Starting Download of Testnet 11 DB"
      aria2c --seed-time=0 --dir=. https://torrents.chia.net/databases/testnet11/testnet11.2026-01-01.tar.gz.torrent
      echo "Extracting DB"
      tar -xzvf testnet11.2026-01-01.tar.gz
      ls -la
      echo "Deleting Old Download DB"
      rm testnet11.2026-01-01.tar.gz
      rm testnet11.2026-01-01.tar.gz.torrent
      cd /chia-blockchain || exit 1
    fi
  else
    file_size=$( (du -k "${CHIA_ROOT}/db/blockchain_v2_mainnet.sqlite" 2>/dev/null || echo 0) | cut -f 1)
    echo "Found DB of size ${file_size}k"
    if [[ $file_size -le 1048576 ]]; then
      cd "${CHIA_ROOT}/db/" || exit
      echo "Starting Download of Mainnet DB"
      aria2c --seed-time=0 --dir=. https://torrents.chia.net/databases/mainnet/mainnet.2026-01-01.tar.gz.torrent
      echo "Extracting DB"
      tar -xzvf mainnet.2026-01-01.tar.gz
      ls -la
      rm mainnet.2026-01-01.tar.gz
      rm mainnet.2026-01-01.tar.gz.torrent
      cd /chia-blockchain || exit 1
    fi
  fi
fi

if [[ -n ${self_hostname} ]]; then
  yq -i '.self_hostname = env(self_hostname)' "$CHIA_ROOT/config/config.yaml"
else
  yq -i '.self_hostname = "127.0.0.1"' "$CHIA_ROOT/config/config.yaml"
fi

if [[ ${log_to_file} == 'true' ]]; then
  sed -i 's/log_stdout: true/log_stdout: false/g' "$CHIA_ROOT/config/config.yaml"
else
  sed -i 's/log_stdout: false/log_stdout: true/g' "$CHIA_ROOT/config/config.yaml"
fi

if [[ -n ${log_level} ]]; then
  sed -i "s/log_level: INFO/log_level: ${log_level}/g" "$CHIA_ROOT/config/config.yaml"
  sed -i "s/log_level: WARNING/log_level: ${log_level}/g" "$CHIA_ROOT/config/config.yaml"
  sed -i "s/log_level: ERROR/log_level: ${log_level}/g" "$CHIA_ROOT/config/config.yaml"
  sed -i "s/log_level: DEBUG/log_level: ${log_level}/g" "$CHIA_ROOT/config/config.yaml"
else
  sed -i 's/log_level: INFO/log_level: INFO/g' "$CHIA_ROOT/config/config.yaml"
  sed -i 's/log_level: WARNING/log_level: INFO/g' "$CHIA_ROOT/config/config.yaml"
  sed -i 's/log_level: ERROR/log_level: INFO/g' "$CHIA_ROOT/config/config.yaml"
  sed -i 's/log_level: DEBUG/log_level: INFO/g' "$CHIA_ROOT/config/config.yaml"
fi

exec "$@"
