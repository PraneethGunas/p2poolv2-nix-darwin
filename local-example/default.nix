# Example local values.
{
  # The P2Poolv2 node. `source` names the flake input it builds from.
  node = {
    source = "p2poolv2";
    p2pPort = 56886;
    stratumPort = 3333;
    apiPort = 46884;
    electrumPort = 50001;
    # Payout addresses. Shares paid to an address nobody holds the key for are lost.
    bootstrapAddress = "REPLACE_WITH_TB1_ADDRESS";
    soloAddress = "REPLACE_WITH_TB1_ADDRESS";
    minerAddress = "REPLACE_WITH_TP2POOL1_ADDRESS";
  };

  # Mujina driving a Bitaxe Gamma Duo (650) flashed with rhapd-bitaxe-gamma.
  miner = {
    enable = false;
    # Stratum username: the bitcoin address that receives the PPLNS payout.
    payoutAddress = "REPLACE_WITH_TB1_ADDRESS";
  };
}
