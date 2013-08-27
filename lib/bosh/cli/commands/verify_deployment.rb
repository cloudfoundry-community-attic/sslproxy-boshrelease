module Bosh::Cli::Command
  # Upload a specific bosh release (or the latest one) and upload
  # the latest base stemcell, if target bosh does not already
  # have a stemcell uploaded.
  class VerifyDeployment < Base
    include Bosh::Cli::Validation
    include FileUtils

    usage "verify deployment"
    desc "verify current deployment for correct sslproxy configuration"
    def verify_deployment
      deployment_required
      deployment_file = load_yaml_file(deployment)
      
      sslproxy_release = deployment_file["releases"].find {|release| release["name"] == req_release_name }
      unless sslproxy_release
        err("Target deployment does not use #{req_release_name} release; so cannot be verified further")
      end

      step("Ensuring director_uuid explicitly set", "Explicitly set director_uuid to a UUID for production deployments", :non_fatal) do
        deployment_file["director_uuid"] != "ignore"
      end

      sslproxy_job = nil
      step("Checking for at least one sslproxy job template", "No job is running sslproxy job template", :non_fatal) do
        sslproxy_job = deployment_file["jobs"].find do |job|
          if job_templates = job["template"]
            job_templates = [job_templates] if job_templates.is_a?(String)
            job_templates.include?(req_job_template_name)
          end
        end
      end

      if sslproxy_job
        job_name = sslproxy_job["name"]
        job_instances = sslproxy_job["instances"]
        static_ip_network = sslproxy_job["networks"].find { |network| network["static_ips"] }
        step("Checking #{job_name} job for network with static IPs", "Job #{job_name} has no networks with static IPs", :non_fatal) do
          static_ip_network
        end
        if static_ip_network
          static_ips = static_ip_network["static_ips"]
          step("Checking #{job_name} job has one IP per instance", 
               "Job #{job_name} has #{job_instances} instances; but has #{static_ips.size} static IPs", :non_fatal) do
            job_instances == static_ips.size
          end
        end
      end

      properties = deployment_file["properties"]
      router_servers = properties["router"] && properties["router"]["servers"]
      step("Checking properties.router.servers provided", "Set properties.router.servers to list of target CF routers", :non_fatal) do
        router_servers
      end

      ssl = properties["sslproxy"] && properties["sslproxy"]["https"]
      step("Checking for provided SSL certificates", "Defaulting to self-signed certificates", :non_fatal) do
        ssl && ssl["ssl_key"] && ssl["ssl_cert"]
      end

      if ssl && ssl["ssl_key"] && ssl["ssl_cert"]
        step("Verifying certificate matches to certificate key", "Mismatch between primary certificate and cerificate key", :non_fatal) do
          File.open(deployment_certificate_key_tmpfile, "w") do |f|
            f << ssl["ssl_key"]
          end
          File.open(deployment_certificate_tmpfile, "w") do |f|
            f << ssl["ssl_cert"]
          end
          # test based on http://www.tbs-certificats.com/FAQ/en/233.html
          cert_key_modulus = `openssl rsa -noout -modulus -in #{deployment_certificate_key_tmpfile}`.strip
          cert_modulus = `openssl x509 -noout -modulus -in #{deployment_certificate_tmpfile}`.strip
          cert_key_modulus == cert_modulus
        end
      end

      unless errors.empty?
        errors.each do |error|
          say error.make_yellow
        end
      end

    ensure
      rm_rf(deployment_certificate_tmpfile)
      rm_rf(deployment_certificate_key_tmpfile)
    end

    private
    def req_release_name
      "sslproxy"
    end

    def req_job_template_name
      "sslproxy"
    end

    def deployment_certificate_tmpfile
      "/tmp/deployment_certificate_tmpfile.crt"
    end

    def deployment_certificate_key_tmpfile
      "/tmp/deployment_certificate_tmpfile.key"
    end
  end
end
