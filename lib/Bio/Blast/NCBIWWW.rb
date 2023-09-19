require 'net/http'
require 'uri'
require 'stringio'
require 'cgi'

$email = nil
$tool = "biopython"
$NCBI_BLAST_URL = "https://blast.ncbi.nlm.nih.gov/Blast.cgi"
$previous = Time.now

def parse_qblast_ref_page(response_body)
  rid = nil
  rtoe = nil
  response_body.each_line do |line|
    rid = $1.strip if line =~ /RID = (.*)/
    rtoe = $1.strip.to_i if line =~ /RTOE = (.*)/
  end

  if rid.nil? && rtoe.nil?
    raise "No se encontró RID ni RTOE en la página 'please wait', probablemente hubo un error en su solicitud"
  elsif rid.nil?
    raise "No se encontró RID en la página 'please wait'."
  elsif rtoe.nil?
    raise "No se encontró RTOE en la página 'please wait'."
  end

  return rid, rtoe
end

def qblast(program, database, sequence, url_base=$NCBI_BLAST_URL, **options)
  params = {
    "CMD" => "Put",
    "PROGRAM" => program,
    "DATABASE" => database,
    "QUERY" => sequence
  }.merge(options)

  if url_base == $NCBI_BLAST_URL
    params["email"] = $email
    params["tool"] = $tool
  end

  params = params.compact

  uri = URI.parse(url_base)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'

  request = Net::HTTP::Post.new(uri.request_uri)
  request.set_form_data(params)
  
  response = http.request(request)
  rid, rtoe = parse_qblast_ref_page(response.body)

  delay = 20 # seconds

  while true
    current = Time.now
    wait = $previous + delay - current
    sleep(wait) if wait > 0
    $previous = current
    
    delay = 60 if delay < 60 && url_base == $NCBI_BLAST_URL
    
    get_params = {
      "CMD" => "Get",
      "RID" => rid
    }.merge(options)
    
    get_params = get_params.compact
    get_request = Net::HTTP::Post.new(uri.request_uri)
    get_request.set_form_data(get_params)

    get_response = http.request(get_request)
    results = get_response.body

    if results != "\n\n" && !results.include?("Status=")
      break
    end
  end

  return StringIO.new(results)
end

# Ejemplo de uso
# results = qblast("blastn", "nr", "ACTGACTGACTG")
