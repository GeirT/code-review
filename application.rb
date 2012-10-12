require "sinatra"
require "json"
require "pony"

configure do
  # A string describing the odds of a code review (e.g. "1:10").
  set :odds, ENV["ODDS"]

  # A list of strings describing e-mail addresses a code review may be addressed to.
  set :recipients, ENV["RECIPIENTS"].split(",")
end

Pony.options = {
  via: :smtp,
  via_options: {
    address: 'smtp.sendgrid.net',
    port: '587',
    domain: 'heroku.com',
    user_name: ENV['SENDGRID_USERNAME'],
    password: ENV['SENDGRID_PASSWORD'],
    authentication: :plain,
    enable_starttls_auto: true
  }
}

post "/" do
  data = JSON.parse request.body.read

  x, y = settings.odds.split ":"
  chance = ((x.to_f / (y.to_f - 1)) * 100)

  data["commits"].each do |commit|
    if rand(100) <= chance
      eligible_recipients = settings.recipients.reject { |recipient| recipient =~ /#{commit["author"]["email"]}/ }

      raise StandardError, "No eligible recipients" if eligible_recipients.empty?

      recipient = eligible_recipients.sample

      Pony.mail({
        to: recipient,
        bcc: "johannes@hyper.no",
        from: "Hyper <no-reply@hyper.no>",
        subject: "You've been selected to review #{commit["author"]["name"]}'s commit",
        body: erb(:reviewer_email, locals: {
          reviewee: commit["author"]["name"],
          url: commit["url"]
        })
      })

      Pony.mail({
        to: commit["author"]["email"],
        bcc: "johannes@hyper.no",
        from: "Hyper <no-reply@hyper.no>",
        subject: "Your commit has been selected for review",
        body: erb(:reviewee_email, locals: {
          reviewer: recipient,
          url: commit["url"]
        })
      })
    end
  end

  ""
end
