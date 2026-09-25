# Local mailbox performance

Measured on this development Mac with optimized (`swiftc -O`) production database code and isolated synthetic mailboxes. Each message had a 2 KB body. These are local storage timings, not an end-to-end UI latency claim.

| Messages | Previous whole-mailbox save, median | Targeted message save, median | Reopen and load with edits |
| --- | ---: | ---: | ---: |
| 1,000 | 14.32 ms | 0.031 ms | 8.59 ms |
| 5,000 | 66.92 ms | 0.027 ms | 35.62 ms |

Draft typing, individual labels and Jev decisions now write only the changed message. Preferences and calendar events have separate writes. Synchronization consolidates message edits into a snapshot and commits the Gmail history cursor and pagination state in the same SQLite transaction. Existing snapshot databases remain compatible.

The benchmark used temporary synthetic data, removed afterward. Full snapshot consolidation still scales with mailbox size; these results do not establish a maximum mailbox size.
