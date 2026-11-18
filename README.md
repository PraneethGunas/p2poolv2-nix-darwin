# p2poolv2-nix-darwin

A P2Poolv2 node and a Bitaxe miner on macOS, managed with
[nix-darwin](https://github.com/nix-darwin/nix-darwin).

Each service runs as a launchd daemon under its own user:

- `bitcoind-testnet5`: bitcoind from Bitcoin Core PR #35861 (Testnet 5
  (BIP95)), on the BIP 95 testnet5 chain, peering with
  `lapis.erisian.com.au` and `tn5.21m.dev`. It keeps about 550 MB of
  blocks, a 100 MB UTXO cache, a 50 MB mempool and 16 peers, with the
  wallet disabled.
- `p2poolv2-main`: P2Poolv2 from upstream `main`, with the Electrum server
  enabled
- `mujina`: [Mujina](https://github.com/256foundation/mujina) driving a
  Bitaxe Gamma Duo (650) over USB, mining to the node's stratum port

## Layout

| Path | Contents |
|------|----------|
| `flake.nix` | Inputs and outputs |
| `local-example/` | Example deployment values |
| `hosts/mac/default.nix` | Host settings |
| `hosts/mac/node.nix` | bitcoind, the P2Poolv2 node and the miner, wired together |
| `networks/testnet5.nix` | testnet5 bitcoind build, flags and ports |
| `modules/services/bitcoind.nix` | `services.bitcoind` |
| `modules/services/p2poolv2.nix` | `services.p2poolv2.instances.<name>` |
| `modules/services/rpc-credentials.nix` | Per-node bitcoind RPC credentials |
| `modules/services/mujina.nix` | `services.mujina` |
| `pkgs/bitcoind-testnet5/package.nix` | bitcoind built from the testnet5 PR branch |
| `pkgs/mujina/package.nix` | `mujina-minerd` built from source |
| `pkgs/mujina/gamma-duo.patch` | Two chips at 400 MHz for the Bitaxe Gamma Duo (650) |

## Requirements

- An Apple silicon Mac
- [Determinate Nix](https://docs.determinate.systems/determinate-nix/).
  nix-darwin leaves the Nix installation, the daemon and
  `/etc/nix/nix.conf` to it.
- For mining, a Bitaxe Gamma Duo (650) flashed with
  [rhapd-bitaxe-gamma](https://github.com/256foundation/rhapd-bitaxe-gamma).
  Upstream Mujina supports only the single-chip Bitaxe Gamma, and the patched
  build supports only the Duo.

nix-darwin leaves `/etc/zshrc` and `/etc/bashrc` unmanaged.

## Configuration

Deployment values live in the `local` input, which defaults to
`local-example/`. `local/` is git-ignored.

```sh
cp -r local-example local
```

Set in `local/default.nix`:

- `node.bootstrapAddress`, `node.soloAddress`: a `tb1...` address
- `node.minerAddress`: a `tp2pool1...` address
- `miner.enable`: `true` once the Bitaxe Gamma Duo runs rhapd-bitaxe-gamma
- `miner.payoutAddress`: a `tb1...` address, sent as the stratum username

Pass `--override-input local path:./local` to every build and switch. The
override is not written to `flake.lock`.

## Apply

The first switch runs nix-darwin from its flake:

```sh
sudo nix run 'github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild' -- \
  switch --flake '.#mac' --override-input local path:./local
```

Later switches use the installed `darwin-rebuild`:

```sh
sudo /run/current-system/sw/bin/darwin-rebuild \
  switch --flake '.#mac' --override-input local path:./local
```

## Services

| Daemon | State | Log |
|--------|-------|-----|
| `bitcoind-testnet5` | `/var/lib/bitcoind-testnet5` | `debug.log` in the state directory |
| `p2poolv2-main` | `/var/lib/p2poolv2-main` | `logs/p2pool.log.<date>` in the state directory, one file per day |
| `mujina` | none | `/var/log/mujina.log` |

`/var/log/<daemon>.log` also holds each daemon's console output.

```sh
sudo launchctl print system/org.nixos.p2poolv2-main
sudo launchctl kickstart -k system/org.nixos.p2poolv2-main
```

The daemons stop while the Mac sleeps.

## Electrum and API

The Electrum server, the P2Poolv2 API and the Mujina API listen on
`127.0.0.1` only:

| Service | Address |
|---------|---------|
| Electrum | `127.0.0.1:50001` |
| P2Poolv2 API | `127.0.0.1:46884` |
| Mujina API | `127.0.0.1:7785` |

## RPC credentials

Each node gets its own bitcoind RPC user, generated on the first switch
with Bitcoin Core's `rpcauth.py` and stored in `/var/lib/p2poolv2-rpc`.
Node users may call only the RPCs P2Poolv2 uses.

## Share chain reset

When a P2Poolv2 release resets the testnet5 share chain or bitcoind chain:

```sh
nix flake update
sudo launchctl bootout system/org.nixos.p2poolv2-main
sudo launchctl bootout system/org.nixos.bitcoind-testnet5
sudo rm -rf /var/lib/bitcoind-testnet5 /var/lib/p2poolv2-main
sudo /run/current-system/sw/bin/darwin-rebuild \
  switch --flake '.#mac' --override-input local path:./local
```

## License

MIT. See [LICENSE](LICENSE).
