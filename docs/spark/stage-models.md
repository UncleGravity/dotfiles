# Model staging over the Spark fabric

Archive a pinned Hugging Face artifact once and materialize one verified local
replica on a Spark. Other Sparks can then pull that immutable artifact over
`fabric0` without reading the NAS:

```bash
ssh spark-02.local models ensure \
  poolside/Laguna-S-2.1-NVFP4@b482b5d57fda6e4e562a652869bde24ba2a57c92 \
  --source spark-01
```

Each Spark runs a read-only rsync daemon bound to its `10.100.0.x` address. The
node name is resolved through `/etc/infer/inventory.json`; callers do not supply
an address or arbitrary rsync path. The receiver copies the complete artifact
into `/srv/models/.staging`, resumes interrupted files, verifies every byte
against the included manifest, and atomically publishes the final path.

Both physical fabric ports share a Layer-2 network. The Spark networking module
uses Linux ARP announcement and reply controls so each logical fabric address is
resolved only through the interface that owns it.

The source daemon permits one outgoing stream. Cluster preparation therefore
stages missing nodes sequentially. `fabric1`, parallel shard transfer, tree
fan-out, and compression are intentionally deferred until measurements show
that NVMe or `fabric0` is not already the limiting resource.

Inference containers continue to mount identical verified local paths read-only.
They never load weights from NFS or the rsync daemon.

## Measured baseline

The 2.23 GB Laguna draft artifact has copied in about one second and completed
its full workflow in about eight seconds. The 71.9 GB primary artifact has
transferred in about 22 seconds, approximately 3.3 GB/s, then passed full
SHA-256 verification and atomic publication. These figures are a baseline, not
a performance contract.
