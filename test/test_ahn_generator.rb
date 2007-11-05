require File.join(File.dirname(__FILE__), "test_generator_helper.rb")

class TestAhnGenerator < Test::Unit::TestCase
  include RubiGen::GeneratorTestHelper

  def setup
    bare_setup
  end
  
  def teardown
    bare_teardown
  end
  
  # Some generator-related assertions:
  #   assert_generated_file(name, &block) # block passed the file contents
  #   assert_directory_exists(name)
  #   assert_generated_class(name, &block)
  #   assert_generated_module(name, &block)
  #   assert_generated_test_for(name, &block)
  # The assert_generated_(class|module|test_for) &block is passed the body of the class/module within the file
  #   assert_has_method(body, *methods) # check that the body has a list of methods (methods with parentheses not supported yet)
  #
  # Other helper methods are:
  #   app_root_files - put this in teardown to show files generated by the test method (e.g. p app_root_files)
  #   bare_setup - place this in setup method to create the APP_ROOT folder for each test
  #   bare_teardown - place this in teardown method to destroy the TMP_ROOT or APP_ROOT folder after each test
  
  def test_generator_without_options
    run_generator('ahn', [APP_ROOT], sources)
    assert_directory_exists "components/simon_game/lib"
    assert_directory_exists "components/simon_game/test"
    assert_directory_exists "config"

    assert_generated_file   "components/simon_game/configuration.rb"
    assert_generated_file   "components/simon_game/lib/simon_game.rb"
    assert_generated_file   "components/simon_game/test/test_helper.rb"
    assert_generated_file   "components/simon_game/test/test_simon_game.rb"
    assert_generated_file   "config/startup.rb"
    assert_generated_file   "dialplan.rb"
    assert_generated_file   "README"
    assert_generated_file   "Rakefile"
    
    assert_generated_class  "components/simon_game/lib/simon_game" do |body|
      assert_has_method body, "initialize"
      assert_has_method body, "start"
      assert_has_method body, "random_number"
    end
  end
  
  private
  def sources
    [RubiGen::PathSource.new(:test, File.join(File.dirname(__FILE__),"..", generator_path))
    ]
  end
  
  def generator_path
    "app_generators"
  end
end
