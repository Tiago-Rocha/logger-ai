# Interview Talking Points

✅ **API clarity** – host app only uses `register`, `configure`, `log`, `delegate`.  
✅ **Persistence** – logs stored locally, guaranteeing delivery even after crash.  
✅ **Declarative configuration** – `LogUploadPolicy` describes *intent*; adapters translate to native schedulers.  
✅ **Feedback loop** – delegate communicates success/failure back to app.  
✅ **Idempotency** – batches deduplicated using `recordId` or `batchId`.  
✅ **Testing strategy** –  
   - Unit: policy validation, mapping correctness.  
   - Fakes: simulate WorkManager/BGTaskScheduler.  
   - Integration: end-to-end log→upload flow.  
   - Contract: cross-platform parity.  
   - Edge: offline, crash, battery-low.  

> “The SDK provides a unified, declarative API for reliable background log uploads across iOS and Android.  
> It abstracts platform differences through a `LogUploadPolicy` adapter layer, persists logs locally for crash resilience, and provides feedback via a delegate.  
> The design prioritizes clarity, reliability, and cross-platform parity.”
