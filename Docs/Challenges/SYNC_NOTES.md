# Sync Notes: Challenge 3.1 (reference solution)

## 1. Transfer type per payload

| Payload | Transfer type | Why |
|---|---|---|
| Today's summary | `updateApplicationContext` | It's *state*, not history. Only the latest value matters, and the system coalesces: if the phone updates 20 times while the watch sleeps, the watch wakes to just the newest one. Cheap and never out of date. |
| Quick Log activity | `transferUserInfo` | A discrete record that must not be lost or merged with others. Each one is queued, delivered in order, and survives either app being killed or relaunched. |
| Voice memo | `transferFile` | Binary data that's too large for a dictionary. It's queued and delivered in the background like userInfo, and the memo JSON rides along in `metadata`. |

## 2. Why not `sendMessage`?

`sendMessage` only works while the counterpart is **reachable** (`isReachable == true`),
which in practice means the other app is in the foreground. Nothing gets queued. A phone
in a pocket is backgrounded or suspended, so the call fails with `notReachable` and the
payload is lost unless we build our own retry queue. The three transfer types above
already are that queue.

`sendMessage` is the right tool for **live, interactive** exchanges where a late delivery
is useless. For example, a "remote shutter" or "start recording on the phone" button on
the watch while the iPhone app is open, or a live heart-rate readout on the phone during
a workout. You want the reply now or not at all.

## 3. Why copy the file before the `Task`?

`WCSessionFile.fileURL` points into a system inbox that WatchConnectivity **deletes as
soon as `session(_:didReceive:)` returns**. The `Task { @MainActor in ... }` runs later,
after the method has returned. If the copy moved inside the `Task`, `copyItem` would
fail with "no such file", and the memo would never appear on the phone, with no crash to
hint at why. Do the copy synchronously in the callback, then hand off only our own copy.

## Bonus: why Resend doesn't duplicate

The resent memo has the **same `id` and `fileName`**. On the phone,
`AppModel.onReceiveMediaFile` removes any existing file at
`mediaDirectory/<fileName>` before moving the new one in, and
`MediaStore.register(_:)` removes any memo with the same `id` before inserting.
Receiving the same memo twice is idempotent: it replaces instead of adding.

## Design notes

- **Where status lives:** `pendingMemoIDs`, `failedMemoIDs`, and `pendingRecordCount`
  live in `ConnectivityManager`, because only it sees the `didFinish` callbacks. The
  views just read them.
- **Relaunch:** on activation, both pending values are rebuilt from
  `outstandingFileTransfers` / `outstandingUserInfoTransfers`. That's why the memo's ID
  also goes into the metadata as a plain `memoID` string: it can be read back without
  decoding the whole memo.
- **Couldn't send at all:** if there's no counterpart (`canSend == false`), the memo is
  marked *failed* rather than left looking delivered, so Resend is offered.
- **Known limitation:** `failedMemoIDs` is in memory only, so a failure is forgotten
  when the watch app relaunches, and that memo then shows as delivered. Persisting it
  (e.g. in `UserDefaults`) would be a good next step.
