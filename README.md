# DSL playground
for research DSL purpose

# Execute flow
## Declare jobs

```ruby
require_relative './wf/item'

class A < Wf::Item; end

class E < A
end
class B < A; end
class C < E; end
class D < E; end
```

## Delare flow
```ruby
class TestWf < Wf::Workflow
  def configure
    run A
    run B, after: A
    run C, after: A
    run E, after: [B, C]
    run D, after: [E]
  end
end

```

### Execute flow
```ruby
wf = TestWf.new
wf.start!
```

### Output
```
sleeping A
Wake up A
sleeping B
sleeping C
Wake up B
Wake up C
sleeping E
Wake up E
sleeping D
Wake up D
```
