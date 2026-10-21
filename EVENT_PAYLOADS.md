# Event payload policy

Extension events identify the changed subject by its object ID
(`composition_id`, `recording_id`, or `release_id`). Composition and Recording
events carry no share type parameters; authorization uses the subject's
matching admin capability, not a currency type.

Events include the affected key where applicable (language, party, genre, or
track index) and the new value only when that value is bounded at roughly 300
BCS bytes or less. Larger content is read from extension storage after the
event: `ReleaseDescriptionSetEvent` carries only `release_id`, and
`CompositionLyricsSetEvent` carries the composition and language but never the
lyrics body. Capability IDs, prior-state snapshots, senders, timestamps, and
other derivable or envelope data are not duplicated in payloads.

One payload exceeds the bound: `RecordingCreditAddedEvent` carries the stored
roles, which are one to three bytes each for most roles, but ten
`Instrumentalist` roles with 100-byte instrument names reach 1,105 bytes.

Each package README lists its current events, fields, and payload sizes. Those
sizes describe BCS payload bytes, excluding the transaction and event envelope;
they are not gas or throughput measurements.

Indexers use the event types of the package generation they follow and read
the subject ID from each event. Old event types remain associated with their
previous deployments. Core publication and `ReleaseConsent` changes do not make
metadata events evidence of economic ownership or licensing.
