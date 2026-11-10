<?php

namespace Drenso\DeployerBundle\Command;

use Drenso\DeployerBundle\Generator\UpdatePageGeneratorFactory;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;
use Symfony\Component\Filesystem\Path;

class GenerateUpdatePagesCommand extends Command
{
  /** @phpstan-ignore missingType.iterableValue */
  public function __construct(
    private readonly UpdatePageGeneratorFactory $generatorFactory,
    private readonly string $projectDir,
    private readonly string $controllerDir,
    private readonly string $contentDir,
    private readonly array $configurations,
  ) {
    parent::__construct();
  }

  protected function configure(): void
  {
    $this
      ->setDescription('Generate the configured update pages');
  }

  public function run(InputInterface $input, OutputInterface $output): int
  {
    $io = new SymfonyStyle($input, $output);

    $controllerPath = $this->resolveFolder($this->controllerDir);
    $contentPath    = $this->resolveFolder($this->contentDir);

    foreach ($this->configurations as $name => $configuration) {
      $contentName                  = $name . '.html';
      $configuration['content_dir'] = Path::makeRelative(Path::join($contentPath, $contentName), $this->projectDir);

      $generator = $this->generatorFactory->getGenerator($configuration);

      file_put_contents(Path::join($controllerPath, $name . '.php'), $generator->generateController());
      file_put_contents(Path::join($contentPath, $contentName), $generator->generateHtml());
    }

    $io->success('Generated new update pages');

    return Command::SUCCESS;
  }

  private function resolveFolder(string $folder): string
  {
    if (!file_exists($folder)) {
      mkdir($folder, 0755, true);
    }

    return $folder;
  }
}
