class HouseKeeperWorker < BackgrounDRb::MetaWorker
  set_worker_name :house_keeper_worker
  
  def create(args = nil)

  end
  
  def remove_unverified_user(user_id = nil)
    unless user_id.nil?
      user = User.find(user_id)
      if !user.nil? and !user.verified? and user.verified_at.nil?
        puts "[#{Time.now()}] User '#{user.given_name} #{user.surname}' - (#{user.username}) didn't validate it's account. I'm going to remove him/her..."
        user.destroy
      end
    end
    persistent_job.finish!
  end
  
  def new_account_external_command(user_id = nil)
    unless user_id.nil?
      user = User.find(user_id)
      if !user.nil?
        puts "[#{Time.now()}] Executing external command for user '#{user.given_name} #{user.surname}' - (#{user.username})"
        begin
          command = Configuration.get('new_account_external_command')
          if command.length > 0
            begin
              fd = IO.popen(command, "w")
              fd.puts(user.to_xml)
              puts "[#{Time.now()}] External command exit status: " + $?.exitstatus.to_s
              fd.close
            rescue
              puts "[#{Time.now()}] Problem executing external command '#{command}'"
            end
          else
            puts "[#{Time.now()}] No external command specified"
          end
        rescue
          puts "[#{Time.now()}] Missing 'new_account_external_command' configuration key"
        end
      end
    end
  end
  
  def remove_stale_sessions
    puts "[#{Time.now()}] Removing stale sessions record..."
    ActiveRecord::SessionStore::Session.destroy_all("updated_at < '#{1.month.ago.to_s(:db)}'")
  end

  def remove_stale_bdrbs
    puts "[#{Time.now()}] Removing stale bdrbs jobs..."
    jobs = BdrbJobQueue.destroy_all("finished_at < '#{2.month.ago.to_s(:db)}'")
    jobs.each { |j| $stderr.puts "* Worker name: #{j.worker_name} - Method: #{j.worker_method} - Key: #{j.job_key} DESTROYED" }
  end

end

