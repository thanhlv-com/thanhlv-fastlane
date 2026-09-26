# Unit of Work Dependency

```mermaid
flowchart TD
    UOW01["UOW-01: Apple Registration Helper (Core Logic)"]
    UOW02["UOW-02: Fastlane Lanes Integration (iOS, macOS, Root)"]
    UOW03["UOW-03: Makefile & Interactive CLI Menu"]
    UOW04["UOW-04: E2E Validation & Documentation"]

    UOW01 --> UOW02
    UOW02 --> UOW03
    UOW03 --> UOW04
```

## Construction Order
1. **UOW-01**: Build helper logic first so that lanes have tested underlying functions to invoke.
2. **UOW-02**: Integrate into Fastlane lanes, validating both single app and batch runs.
3. **UOW-03**: Wrap lanes with Makefile targets and Interactive CLI menu.
4. **UOW-04**: Complete documentation and dry run validation.
