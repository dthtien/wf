# DSL playground
Gush cloner without ActiveJob but requried Sidekiq. This project is for researching DSL purpose

# Execute flow
## Declare jobs

```ruby
require_relative './wf/item'

class A < Wf::Item
  def perform
    puts "#{self.class.name} Working"
    sleep 2
    puts "#{self.class.name} Finished"
  end
end

class E < A; end
class B < A; end
class C < E; end
class D < E; end
```

## Declare flow
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
wf = TestWf.create
wf.start!
```

### Output
```
A Working
A Finished
B Working
C Working
B Finished
C Finished
E Working
E Finished
D Working
D Finished
```

# References
- https://github.com/chaps-io/gush
- https://github.com/mperham/sidekiq
