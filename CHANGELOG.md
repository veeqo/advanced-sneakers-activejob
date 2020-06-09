## Changes Between 0.3.2 and 0.3.3

### [Add ability to run ActiveJob consumers by queues](https://github.com/veeqo/advanced-sneakers-activejob/pull/9)

Works with `sneakers:active_job` task only!

```sh
rake sneakers:active_job QUEUES=mailers,default
```

## Changes Between 0.3.1 and 0.3.2

### [Add ability to run specified ActiveJob queues consumers](https://github.com/veeqo/advanced-sneakers-activejob/pull/8)

Sneakers allows to specify consumer classes to run:

```sh
WORKERS=MyConsumer rake sneakers:run
```

Now it works for ActiveJob queues consumers as well:

```sh
WORKERS=AdvancedSneakersActiveJob::MailersConsumer rake sneakers:run
```

## Changes Between 0.3.0 and 0.3.1

### [Restore Sneakers::Worker::Classes methods](https://github.com/veeqo/advanced-sneakers-activejob/pull/6)

## Changes Between 0.2.3 and 0.3.0

This release does not change the observed behavior, but replaces the publisher with completely new implementation.

### Reusable parts of publisher are extracted to [bunny-publisher](https://github.com/veeqo/bunny-publisher)

## Changes Between 0.2.2 and 0.2.3

### [Refactored support for ActiveJob prefix](https://github.com/veeqo/advanced-sneakers-activejob/pull/3)
### [Support for custom adapter per job](https://github.com/veeqo/advanced-sneakers-activejob/pull/4)

## Changes Between 0.2.1 and 0.2.2

Cleanup of `puts` and logger mistakenly introduced in previous version

## Changes Between 0.2.0 and 0.2.1

### [Support for ActiveJob prefix](https://github.com/veeqo/advanced-sneakers-activejob/pull/2)

Fixed worker class name in rake task description

## Changes Between 0.1.0 and 0.2.0

### [`message_options`](https://github.com/veeqo/advanced-sneakers-activejob/pull/1)

Customizable options for message publishing (`routing_key`, `headers`, etc)

## Original Release: 0.1.0
