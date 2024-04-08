if defined?(LetterOpenerWeb) && Rails.configuration.action_mailer.delivery_method == :letter_opener_web
  LetterOpenerWeb.configure do |config|
    config.aws_access_key_id = ENV['S3_KEY']
    config.aws_secret_access_key = ENV['S3_SECRET']
    config.aws_region = ENV['AWS_REGION'] || "eu-west-1"
    config.aws_bucket = ENV['S3_BUCKET']
    config.letters_storage = :s3
    config.letters_location = "cache/letter_opener"
  end
end
