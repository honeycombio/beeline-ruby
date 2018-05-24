# Our instrumented apps are attempting to mimic real app codebases (albeit
# simplified ones), most of which assume they are the only app running in a
# given Ruby interpreter instance. Moreover we want to include Honeycomb.init in
# the behaviour under test, which is designed to be called once per interpreter
# instance.
#
# Therefore we run separate test runs, one for each app. To remove the footguns
# possible via an unwary run of 'rspec' (which would try to run all the specs
# and therefore load all the apps), we have each app class include this module,
# to provide a clearer error message in this case.
module ThereCanBeOnlyOneApp
  class Error < LoadError; end

  def self.included(mod)
    if defined?(@already_included)
      raise Error, "Can't initialize #{mod}, already initialized #{@already_included}", caller.drop(2)
    end
    @already_included = mod
    super
  end
end
