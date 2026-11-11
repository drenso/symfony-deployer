<?php

namespace Drenso\DeployerBundle\DependencyInjection;

use Symfony\Component\Config\Definition\Builder\TreeBuilder;
use Symfony\Component\Config\Definition\ConfigurationInterface;
use Symfony\Component\Filesystem\Path;

class Configuration implements ConfigurationInterface
{
  /** @return TreeBuilder<'array'> */
  public function getConfigTreeBuilder(): TreeBuilder
  {
    $treeBuilder = new TreeBuilder('drenso_deployer');

    $rootNode = $treeBuilder->getRootNode();
    $rootNode->children()
        ->scalarNode('base_dir')
        ->info('The path where the deployment related files are to be found')
        ->defaultValue(Path::join('%kernel.project_dir%', 'deploy'));

    $rootNode->children()
        ->scalarNode('controllers_dir')
        ->info('The path where the update controllers are to be found')
        ->defaultValue('controllers');

    $rootNode->children()
        ->scalarNode('content_dir')
        ->info('The path where the update page contents are to be found')
        ->defaultValue('content');

    $rootNode->children()
        ->scalarNode('script_dir')
        ->info('The path where the deployment scripts are to be found')
        ->defaultValue('scripts');

    $rootNode->children()
        ->scalarNode('namespace')
        ->info('The namespace of the deployment scripts')
        ->defaultValue('DrensoDeployer');

    $rootNode->children()
        ->scalarNode('generator_enabled')
        ->info('Whether the generator command is available')
        ->defaultTrue();

    $rootNode->children()
        ->scalarNode('deploy_indicator')
        ->info('The file that should exists to indicate deployment is running')
        ->defaultValue('.deploying');

    $rootNode->children()
        ->scalarNode('block_messenger_worker_during_deploy')
        ->info('Whether to block messenger worker startup when a deployment is running')
        ->defaultTrue();

    $rootNode->children()
      ->arrayNode('update_pages')
        ->info('A generator for static update pages')
        ->canBeEnabled()
        ->addDefaultsIfNotSet()
        ->children()
          ->booleanNode('preview_controller')
            ->info('Whether the preview controller needs to be registered. Routes still need to be imported manually.')
            ->defaultFalse()
          ->end()
          ->arrayNode('configurations')
            ->info('Update page configurations')
            ->useAttributeAsKey('name')
            ->arrayPrototype()
            ->children()
              ->integerNode('response_code')->info('The response code to use with this page')->defaultValue(503)->end()
              ->scalarNode('page_title')->defaultValue('Updating')->end()
              ->scalarNode('background_color')->defaultValue('#244E95')->end()
              ->scalarNode('svg')->defaultNull()->end()
              ->scalarNode('update_title')->defaultValue('Updating')->end()
              ->scalarNode('update_text')
                ->defaultValue('Unfortunately, we are updating the website right now. However, this shouldn\'t take very long, so please try again in a few minutes!')
              ->end()
              ->integerNode('reload_seconds')->info('Whether to automatically reload the page after x seconds. Can be disabled by setting to 0.')->defaultValue(60)->end()
              ->booleanNode('enable_game')->info('Whether to enable the Chromium dino mini game on the update page')->defaultTrue()->end()
              ->scalarNode('game_header')->defaultValue('Need to pass some time?')->end();

    return $treeBuilder;
  }
}
