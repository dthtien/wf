# Changelog
All notable changes to this project will be documented in this file.
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
