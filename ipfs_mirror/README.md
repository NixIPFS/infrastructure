This config deploys a node that is capable of producing an IPFS mirror of
NixOS releases.

To start the process use `systemctl start update-nixos-release`
If you have a rather fast connection to S3 (>= 100 Mbit/s), you should increase
the amount of processes to speed up mirroring.

Due to funny (not debugged yet, maybe stochastical fails) issues during the
download process, the service may needs to be restarted several times to succeed.

Also systemd eats the last few entries of the journal so you can not see the
IPFS printed out. (yay!)

You can do it bei either resolving the IPNS entry of the host or by
stat'ing the mfs entry like this:

```
ipfs --api /ip4/127.0.0.1/tcp/5001 files stat nixfs_1489091268
```

Have a look at the logfile in the same directory of this file for
progress reports.
