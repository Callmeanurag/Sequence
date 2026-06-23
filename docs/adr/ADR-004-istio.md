# ADR-004: Istio Service Mesh

**Status:** Accepted  
**Date:** 2026-06-22  
**Deciders:** Anurag Raj

---

## Context

Inter-service communication in a microservices architecture requires: TLS encryption, authentication, traffic routing, circuit breaking, retries, timeouts, and observability. These can be implemented in application code or delegated to a service mesh sidecar.

## Decision

Use Istio service mesh with Envoy sidecar injection in all application namespaces.

## Rationale

A service mesh moves cross-cutting concerns (mTLS, retries, circuit breaking, tracing) out of application code into the infrastructure layer. The application code only handles business logic.

**Istio over Linkerd:**

| Dimension | Istio | Linkerd |
|---|---|---|
| Complexity | High | Lower |
| Features | Comprehensive | Focused |
| Proxy | Envoy (xDS, full L7) | Rust (linkerd2-proxy) |
| Traffic management | VirtualService, DestinationRule | ServiceProfile |
| Multi-cluster | Yes | Yes |
| Interview value | Very high | Medium |
| Industry adoption | Netflix, Airbnb, Lyft | Growing |
| CNCF status | Graduated | Graduated |

Istio was chosen because its complexity is the learning. Configuring Envoy, understanding xDS, writing VirtualService and DestinationRule policies — these are skills that appear in senior platform engineering interviews.

## Key Features Used

**mTLS (PeerAuthentication):**
All pod-to-pod communication is mutually authenticated and encrypted. Certificates are SPIFFE-compliant X.509, rotated every 24 hours by Istiod/Citadel. Zero manual certificate management.

**Traffic Splitting (VirtualService + DestinationRule):**
Used for canary deployments. Traffic is split by weight between stable and canary versions. Combined with Flagger for automated promotion/rollback based on Prometheus metrics.

**Circuit Breaking (DestinationRule outlierDetection):**
Pods that exceed consecutive error thresholds are ejected from the load balancer pool. Prevents cascade failures.

**Fault Injection (VirtualService fault):**
Used in chaos engineering exercises. Inject 2-second delays or 503 responses for a percentage of traffic to test circuit breakers and timeout policies.

**Distributed Tracing:**
Envoy automatically propagates trace headers (B3/W3C). Traces appear in Tempo/Jaeger without application code changes.

## Consequences

**Positive:**
- Zero-trust networking: no pod can communicate without a valid SPIFFE certificate
- Traffic management without code changes (canary, circuit breaking, retries)
- Automatic distributed tracing for all service calls
- Consistent observability (Envoy exports metrics for every request)

**Negative:**
- Each pod gets an Envoy sidecar: +50MB memory, +1-2ms latency overhead
- Steep learning curve: VirtualService, DestinationRule, Gateway, ServiceEntry, PeerAuthentication, AuthorizationPolicy are all different CRDs
- Istio upgrade process is complex and requires careful planning

## Interview Guidance

**Question:** "How does Istio implement mTLS?"

Answer: "Istiod (the control plane) runs Citadel, which is a certificate authority. When a pod starts, the Envoy sidecar (injected by a mutating admission webhook) gets a SPIFFE-compliant X.509 certificate from Citadel via the xDS protocol. This certificate represents the pod's identity — specifically its Kubernetes service account — in the format `spiffe://cluster.local/ns/{namespace}/sa/{serviceAccount}`. When two Envoy sidecars communicate, they perform a TLS handshake, verify each other's certificates against the cluster CA, and then establish an encrypted connection. The application sees a plaintext connection on localhost. Certificates rotate every 24 hours automatically. With PeerAuthentication mode STRICT, any pod attempting plaintext communication is rejected at the sidecar level."
