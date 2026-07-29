# Model staging over the Spark fabric

Download large Hugging Face models once on `spark-01.local`, then replicate them
to the other Sparks over the 200 Gbit/s fabric before starting inference. Ray and
vLLM do not distribute model files themselves; every worker should load its
tensor-parallel shard from an identical path on local NVMe.

Proposed workflow:

1. Use `hf download --local-dir` on `spark-01.local` to populate
   `/srv/models/<model>`.
2. Copy the completed directory to the other nodes using explicit fabric host
   aliases. Use a tree transfer so `spark-01.local` does not send all three
   copies sequentially.
3. Verify the revision, file manifest, and transfer completion on every node.
4. Mount the directory read-only at the same container path on all four nodes.
5. Set `HF_HUB_OFFLINE=1`, start Ray, and start vLLM only after every local copy
   is ready.

The staging operation should be declarative and idempotent: pin the Hugging Face
revision, support partial/resumable transfers, copy into a temporary directory,
and atomically mark or rename a verified copy as ready. Compression should be
disabled for weight files. A single SSH or rsync flow will normally use only one
of the two logical fabric paths; saturating the aggregate 200 Gbit/s connection
would require parallel shard transfers across both paths and will likely be
limited by NVMe or encryption throughput first.

Prefer replicated local storage over serving the model from `spark-01.local`
through NFS, which would make model startup depend on one node's storage and
network performance.
