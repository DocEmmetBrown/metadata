#!/usr/bin/env ruby
require "net/http"
require "json"

endpoint = %w[http://169.254.169.254 latest]

$get_urls = {endpoint => nil}
$result_data = {}

def to_url(arr)
  Array(arr).join("/")
end

def fetch_url(uri)
  r = nil
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 1
  http.open_timeout = 1
  begin
    r = http.request_get(uri.path)
  rescue
    p "rescue #{uri.path}" if ENV["DEBUG"]
  end
  r
end

def result(previous, url)
  uri = nil
  begin
    uri = URI(to_url(url))
  rescue
    # if this is not an URI, it's probably that it already
    # includes the result
    $result_data[to_url(previous)] = url.last if previous
    $get_urls.delete(url)
    return
  end
  r = fetch_url(uri)
  $get_urls.delete(url)
  if r.nil?
    p "r is nil #{url}" if ENV["DEBUG"]
    return
  end

  while r.code == "301"
    r = fetch_url(URI(r["location"]))
    if r.nil?
      p "r is nil #{url} after 301" if ENV["DEBUG"]
      return
    end
  end
  if r.code != "200"
    # if there is an error, it's also probably that
    # the previous request was the result
    p "r.code = #{r.code} #{url}" if ENV["DEBUG"]
    $result_data[to_url(previous)] = url.last if previous
    return
  end

  # trying to add a fake new part for the url
  fake_url = url.dup << "xxxx"
  r2 = fetch_url(URI(to_url(fake_url)))
  if r2.nil?
    p "r2 is nil #{url}" if ENV["DEBUG"]
    return
  end
  # if the result is the same, we're at the end of
  # the fetching
  if r.body == r2.body
    p "r = r2 #{url}" if ENV["DEBUG"]
    $result_data[to_url(url)] = r.body
    return
  end
  # if it's a json block or a userdata
  # append it as a whole
  # TODO : find a better diagnostic for
  # multilines output
  if r.body[0] == "{" || url.last == "user-data"
    p "block #{r.body}" if ENV["DEBUG"]
    $result_data[to_url(url)] = r.body
  else
    # otherwise, add all the findings for
    # the new loop
    r.body.split("\n").each do |s|
      s.chop! if s[-1] == "/"
      new_url = url.dup << s
      $get_urls[new_url] = url
    end
  end
end

until $get_urls.empty?
  get_urls = $get_urls.dup
  get_urls.each do |k, v|
    result(v, k)
  end
end

new_result = {}
# only for cleanup
p $result_data if ENV["DEBUG"]

$result_data.sort_by{|k,v| k}.to_h.each do |k, v|
  new_k = k.gsub(endpoint.join("/") + "/", "")
  begin
    new_v = JSON.parse(v)
  rescue
    new_v = v
  end
  new_result[new_k] = new_v
  $result_data.delete k
end
puts JSON.pretty_generate(new_result)
