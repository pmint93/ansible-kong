require '/tmp/kitchen/spec/spec_helper.rb'

kong_conf_dir = '/etc/kong/'
kong_nginx_working_dir = '/usr/local/kong'


describe package('kong-community-edition') do
  it { should be_installed }
end

describe file(kong_conf_dir) do
  it { should be_directory }
  it { should be_mode 755 }
  it { should be_owned_by 'root' }
end

describe file(kong_nginx_working_dir) do
  it { should be_directory }
  it { should be_mode 755 }
  it { should be_owned_by 'root' }
end

describe file("#{kong_conf_dir}/kong.conf") do
  it { should be_file }
  it { should be_mode 644 }
  it { should be_owned_by 'root' }
end

describe file("/etc/logrotate.d/kong") do
  it { should be_file }
  it { should be_mode 644 }
  it { should be_owned_by 'root' }
end

describe file("/usr/local/bin/kong") do
  it { should be_file }
  it { should be_mode 755 }
  it { should be_owned_by 'root' }
end

describe command("/usr/local/bin/kong version") do
  its(:stdout) { should match %r[(Kong version:\s)?0.*]i }
end

describe process("nginx") do
  it { should be_running }
  its(:args) { should match %r(-p /usr/local/kong -c nginx.conf) }
end

# verify svcOne object is configured and svcThree does not exist
describe command("curl -s http://localhost:8001/services | jq '.data[].name'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match 'svcOne' }
  its(:stdout) { should_not match 'svcThree' }
end

# verify svcTwo object is updated
describe command("curl -s http://localhost:8001/services | jq '.data[] | {(.name): .path }'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match 'svc-two-new' }
end

# verify routes of svcOne
describe command("curl -s http://localhost:8001/services/svcOne/routes | jq '.data | length'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '2' }
end
describe command("curl -s http://localhost:8001/services/svcOne/routes | jq '.data[].paths[]'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '"/svcOne"' }
  its(:stdout) { should match '"/svcOnePlus"' }
end

# verify number of enabled plugins of svcOne service object
describe command("curl -s http://localhost:8001/services/svcOne/plugins | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '3' }
end

# verify enabled plugins of svcOne service object
describe command("curl -s http://localhost:8001/services/svcOne/plugins | jq '.data[] | .name'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match 'acl' }
  its(:stdout) { should match 'oauth2' }
  its(:stdout) { should_not match 'rate-limiting' }
  its(:stdout) { should_not match 'key-auth' }
end

# verify enabled plugins of svcTwo service object
describe command("curl -s http://localhost:8001/services/svcTwo/plugins | jq '.data[] | .name'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match 'basic-auth' }
  its(:stdout) { should match 'key-auth' }
  its(:stdout) { should match 'oauth2' }
  its(:stdout) { should_not match 'cors' }
end

# verify number of upstream object
describe command("curl -s http://localhost:8001/upstreams | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '1' }
end

# verify upstream object
describe command("curl -s http://localhost:8001/upstreams | jq '.data[].name'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match 'upstreamTwo' }
end

# verify targets of upstream object
describe command("curl -s http://localhost:8001/upstreams/upstreamTwo/targets | jq '.data[].target'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match 'targetTwo' }
end

# verify consumerOne consumer object exists
describe command("curl -s http://localhost:8001/consumers | jq '.data[] | .username'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match 'consumerOne' }
  its(:stdout) { should match 'consumerThree' }
  its(:stdout) { should_not match 'consumerTwo' }
end

# verify number of basic-auth credentials configured for consumerThree consumer object
describe command("curl -s http://localhost:8001/consumers/consumerThree/basic-auth | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '2' }
end

# verify number of key-auth credentials configured for consumerThree consumer object
describe command("curl -s http://localhost:8001/consumers/consumerThree/key-auth | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '2' }
end

# verify number of oauth2 credentials configured for consumerThree consumer object
describe command("curl -s http://localhost:8001/consumers/consumerThree/oauth2 | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '2' }
end

# verify number of hmac-auth credentials configured for consumerThree consumer object
describe command("curl -s http://localhost:8001/consumers/consumerThree/hmac-auth | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '2' }
end

# verify number of jwt credentials configured for consumerThree consumer object
describe command("curl -s http://localhost:8001/consumers/consumerThree/jwt | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '2' }
end

# verify number of acl groups configured for consumerThree consumer object
describe command("curl -s http://localhost:8001/consumers/consumerThree/acls | jq '.total'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match '1' }
end


# no API keys #
describe command("curl -s -w ':%{http_code}' http://node1.internal:8000/reporting-service | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"No API key found in request\"}:401" }
end

describe command("curl -s -w ':%{http_code}' http://node1.internal:8000/reporting-service/realtime | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"No API key found in request\"}:401" }
end
################

# unauthenticated keys #
describe command("curl -H 'X-Api-Key: invalid-key-1' -w ':%{http_code}' http://node1.internal:8000/reporting-service | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"Invalid authentication credentials\"}:403" }
end

describe command("curl -H 'X-Api-Key: invalid-key-2' -w ':%{http_code}' http://node1.internal:8000/reporting-service/realtime | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"Invalid authentication credentials\"}:403" }
end

describe command("curl -H 'X-Api-Key: invalid-key-3' -w ':%{http_code}' http://node1.internal:8000/reporting-service/no-url | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"Invalid authentication credentials\"}:403" }
end

describe command("curl -H 'X-Api-Key: invalid-key-3' -w ':%{http_code}' http://node1.internal:8000/reporting-service/restricted/realtime | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"Invalid authentication credentials\"}:403" }
end
#########################

# valid keys #
describe command("curl -H 'X-Api-Key: 5-external' -s http://node1.internal:8000/reporting-service | jq -r '.url'") do
  its(:stdout) { should match "http://mockbin.org/request/reporting-service/reporting" }
end

describe command("curl -H 'X-Api-Key: 5-external' -s http://node1.internal:8000/reporting-service/personalcontent | jq -r '.url'") do
  its(:stdout) { should match "http://mockbin.org/request/reporting-service/reporting/personalcontent" }
end

describe command("curl -H 'X-Api-Key: 5-internal' -s http://node1.internal:8000/reporting-service/restricted/realtime | jq -r '.url'") do
  its(:stdout) { should match "http://mockbin.org/request/reporting-service/reporting/realtime" }
end
##############

# unauthorized keys #
describe command("curl -H 'X-Api-Key: 5-internal' -w ':%{http_code}' http://node1.internal:8000/reporting-service | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"You cannot consume this service\"}:403" }
end

describe command("curl -H 'X-Api-Key: 5-internal' -w ':%{http_code}' http://node1.internal:8000/reporting-service/realtime | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"You cannot consume this service\"}:403" }
end

# although this test doesn't produce an unauthorized response, it's resulting upstream URL is invalid and will not correct route
# see README (Shortcutting Paths) for more details
describe command("curl -H 'X-Api-Key: 5-external' -s http://node1.internal:8000/reporting-service/realtime | jq -r '.url'") do
  its(:stdout) { should match "http://mockbin.org/request/reporting-service/reporting" }
end

describe command("curl -H 'X-Api-Key: 5-external' -w ':%{http_code}' http://node1.internal:8000/reporting-service/restricted/realtime | tr -d '\n'") do
  its(:stdout) { should match "{\"message\":\"You cannot consume this service\"}:403" }
end


######################
