<?php

namespace Drenso\DeployerBundle\Messenger;

use Psr\Log\LoggerInterface;
use Symfony\Component\Filesystem\Filesystem;
use Symfony\Component\Filesystem\Path;
use Symfony\Component\Messenger\Event\WorkerStartedEvent;

final readonly class BlockMessengerWorkerDuringDeployListener
{
  public function __construct(
    private string $projectDir,
    private string $deployIndicator,
    private ?LoggerInterface $messengerLogger,
  ) {
  }

  public function __invoke(WorkerStartedEvent $event): void
  {
    $deployIndicatorPath = Path::join($this->projectDir, $this->deployIndicator);

    if (!(new Filesystem())->exists($deployIndicatorPath)) {
      return;
    }

    $this->messengerLogger?->warning('Tried to start worker during deployment, stopping worker!');
    $event->getWorker()->stop();
  }
}
