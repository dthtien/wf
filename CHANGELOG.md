# Changelog
All notable changes to this project will be documented in this file.

## 0.1.12
### Added
#### Dynamic workflows
There might be a case when you have to contruct the workflow dynamically depend on the input
As an example, let's write a workflow which puts from 1 to 100 into the terminal parallely . Additionally after finish all job, it will puts the finshed word into the terminal
```ruby
class FirstMainItem < Dwf::Item
  def perform
    puts "#{self.class.name}: running #{params}"
  end
end

SecondMainItem = Class.new(FirstMainItem)

class TestWf < Dwf::Workflow
  def configure
    items = (1..100).to_a.map do |number|
      run FirstMainItem, params: number
    end
    run SecondMainItem, after: items, params: "finished"
  end
end

```
We can achieve that because run method returns the id of the created job, which we can use for chaining dependencies.
Now, when we create the workflow like this:
```ruby
wf = TestWf.create
# wf.callback_type = Dwf::Workflow::SK_BATCH
wf.start!
```

## 0.1.12
### Added
#### Subworkflow for all callback types
same with `0.1.11`
## 0.1.11
### Added
#### Subworkflow - Only support sidekiq pro
There might be a case when you want to reuse a workflow in another workflow

As an example, let's write a workflow which contain another workflow, expected that the SubWorkflow workflow execute after `SecondItem` and the `ThirdItem` execute after `SubWorkflow`

```ruby
gem 'dwf', '~> 0.1.11'
```

### Setup
```ruby
class FirstItem < Dwf::Item
  def perform
    puts "Main flow: #{self.class.name} running"
    puts "Main flow: #{self.class.name} finish"
  end
end

SecondItem = Class.new(FirstItem)
ThirtItem = Class.new(FirstItem)

class FirstSubItem < Dwf::Item
  def perform
    puts "Sub flow: #{self.class.name} running"
    puts "Sub flow: #{self.class.name} finish"
  end
end

SecondSubItem = Class.new(FirstSubItem)

class SubWorkflow < Dwf::Workflow
  def configure
    run FirstSubItem
    run SecondSubItem, after: FirstSubItem
  end
end


class TestWf < Dwf::Workflow
  def configure
    run FirstItem
    run SecondItem, after: FirstItem
    run SubWorkflow, after: SecondItem
    run ThirtItem, after: SubWorkflow
  end
end

wf = TestWf.create
wf.start!
```

### Result
```
Main flow: FirstItem running
Main flow: FirstItem finish
Main flow: SecondItem running
Main flow: SecondItem finish
Sub flow: FirstSubItem running
Sub flow: FirstSubItem finish
Sub flow: SecondSubItem running
Sub flow: SecondSubItem finish
Main flow: ThirtItem running
Main flow: ThirtItem finish
```

## 0.1.10
### Added
- Allow to use argument within workflow and update the defining callback way
```
class TestWf < Dwf::Workflow
  def configure(arguments)
    run A
    run B, after: A, params: argument
    run C, after: A, params: argument
  end
end

wf = TestWf.create(arguments)
wf.callback_type = Dwf::Workflow::SK_BATCH

```
- Support `find` workflow and `reload` workflow
```
wf = TestWf.create
Dwf::Workflow.find(wf.id)
wf.reload
```

## 0.1.9
### Added
### Fixed
- fix incorrect argument at configuration

## 0.1.8
### Added
- add pinlining feature

```ruby
class SendOutput < Dwf::Item
  def perform
    output('it works')
  end
end

```

`output` method used to output data from the job to add outgoing jobs

```ruby
class ReceiveOutput < Dwf::Item
  def perform
    message = payloads.first[:output] # it works
  end
end
```

`payloads` is an array that containing outputs from incoming jobs

```
[
  {
    id: "SendOutput|1849a3f9-5fce-401e-a73a-91fc1048356",
    class: "SendOutput",
    output: 'it works'
  }
]
```

```ruby
Dwf.config do |config|
  config.opts = { url 'redis://127.0.0.1:6379' }
  config.namespace = 'dwf'
end
```

## 0.1.7
### Added
- Allow to config redis and queue

```ruby
Dwf.config do |config|
  config.opts = { url 'redis://127.0.0.1:6379' }
  config.namespace = 'dwf'
end
```

## 0.1.6
### Added
- Sidekiq batch callback: separate batches

## 0.1.5
### Added
- add github action with build and public gem flow

## 0.1.4
### Added
- Add testes
- add github action

### Fixed
- Remove Sidekiq pro by default

---
## 0.1.3
### Added
- Support both build in and [Sidekiq batches](https://github.com/mperham/sidekiq/wiki/Batches) callback
- Update readme

### Fixed
- Fix bug require development gem

---
## 0.1.2
### Added
- Support [Sidekiq batches](https://github.com/mperham/sidekiq/wiki/Batches) callback
- Update readme

### Fixed
- fix typo and remove development gem

---
## 0.1.0
### Added
- init app with basic idea following [Gush](https://github.com/chaps-io/gush) concept
- Support build in callback
