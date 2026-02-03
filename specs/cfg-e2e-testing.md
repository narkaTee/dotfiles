# cfg E2E Testing

## Overview

E2E tests for `cfg` that verify spec conformance using real SSH agents and encryption, with only the fzf picker replaced for deterministic selection. Tests are scenario-based, mapping directly to usecases in the cfg spec.

## Key Constraints & Design Decisions

**Real components:**
- Real SSH agent with ephemeral Ed25519 keys
- Real AES-256-CBC encryption/decryption
- Real file I/O to temp directories
- Real YAML parsing and serialization

**Mocked components:**
- fzf picker only - replaced with a configurable test picker

**Picker abstraction:**
- Single module-level `picker` function in `selector.rb`
- Same picker used by `cli.rb` for SSH key and profile selection
- Tests inject a fake picker that returns predetermined selections
- Picker signature: `picker(items, prompt) -> String | nil`

**Test organization:**
- Scenarios grouped by spec section (profile selection, management, execution)
- Each scenario is a hash with inputs, expected outputs, and picker config
- RSpec shared examples for compact, readable coverage

## Usage

### Picker stub

```ruby
RSpec.configure do |config|
  config.before(:each) do
    # Default: no picker interaction expected
    allow(Cfg::Selector).to receive(:pick).and_return(nil)
  end
end

def pick(answer)
  # Integer: select nth item
  # String: select item containing string
  # Proc: custom selection logic
  allow(Cfg::Selector).to receive(:pick) do |items, _prompt|
    case answer
    when Integer then items[answer]
    when String then items.find { |i| i.include?(answer) }
    when Proc then answer.call(items)
    end
  end
end
```

### Scenario test pattern

```ruby
PROFILE_SELECTION_SCENARIOS = [
  { id: "direct", args: ["--select", "claude.work"],
    profiles: [["claude.work", "Work"]], expect: "claude.work" },
  { id: "auto-single", args: ["--select", "claude"],
    profiles: [["claude.work", "Work"]], expect: "claude.work" },
  { id: "fzf-multi", args: ["--select", "claude"], pick: 1,
    profiles: [["claude.work", "Work"], ["claude.personal", "Personal"]],
    expect: "claude.personal" },
]

PROFILE_SELECTION_SCENARIOS.each do |s|
  it "profile selection: #{s[:id]}" do
    s[:profiles].each { |name, desc| create_profile(name, desc) }
    pick(s[:pick]) if s[:pick]

    result = run_cfg(s[:args])

    expect(result.stdout.strip).to eq(s[:expect])
  end
end
```

### Spec sections to cover

1. **Profile selection** - direct, auto-select, fzf picker
2. **Management commands** - list, add, import, show, edit, delete
3. **Execution modes** - run command, export-env, export-file
4. **Multi-key behavior** - no keys, one key, multiple keys, key rotation
5. **Error cases** - missing profile, missing template, file exists
