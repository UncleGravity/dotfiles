import assert from "node:assert/strict"
import test from "node:test"
import { Effect, Fiber, TestClock, TestContext } from "effect"
import { makeHealthProbe } from "../src/adapters/health-probe.js"

const request = (
  handler: (url: string, signal: AbortSignal) => Promise<Response>
): typeof globalThis.fetch =>
  ((input: string | URL | Request, init?: RequestInit) =>
    handler(String(input), init?.signal!)) as typeof globalThis.fetch

test("health probes classify HTTP and transport outcomes", async () => {
  const urls: Array<string> = []
  const probe = makeHealthProbe(
    request((url) => {
      urls.push(url)
      return Promise.resolve(
        new Response(null, { status: url.endsWith("/ok") ? 204 : 503 })
      )
    })
  )

  assert.equal(
    await Effect.runPromise(probe.reachable("http://service.test/ok")),
    true
  )
  assert.equal(
    await Effect.runPromise(probe.reachable("http://service.test/unavailable")),
    false
  )

  const failed = makeHealthProbe(
    request(() => Promise.reject(new Error("connection refused")))
  )
  assert.equal(
    await Effect.runPromise(failed.reachable("http://service.test/error")),
    false
  )
  assert.deepEqual(urls, [
    "http://service.test/ok",
    "http://service.test/unavailable"
  ])
})

test("health probe timeout aborts the pending request", async () => {
  let aborted = false
  const probe = makeHealthProbe(
    request(
      (_url, signal) =>
        new Promise((_resolve, reject) => {
          signal.addEventListener(
            "abort",
            () => {
              aborted = true
              reject(new Error("aborted"))
            },
            { once: true }
          )
        })
    ),
    "50 millis"
  )

  const reachable = await Effect.runPromise(
    Effect.gen(function* () {
      const fiber = yield* Effect.fork(
        probe.reachable("http://service.test/hangs")
      )
      yield* TestClock.adjust("50 millis")
      return yield* Fiber.join(fiber)
    }).pipe(Effect.provide(TestContext.TestContext))
  )

  assert.equal(reachable, false)
  assert.equal(aborted, true)
})
