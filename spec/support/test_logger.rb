require 'logger'

$test_logger = Logger.new($stderr)
if ENV['DEBUG']
  $test_logger.level = Logger::DEBUG
else
  $test_logger.level = Logger::WARN
end
