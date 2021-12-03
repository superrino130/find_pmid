require 'sinatra'
require 'sinatra/reloader'
require 'open-uri'
require 'bio'
require 'mechanize'
require 'date'

def jpost_rev(id, rev)
  "https://repository.jpostdb.org/xml/" + id + ".#{rev}.xml"
end

def get_jpost(id)
  begin
    id = 'JPST' + format("%06d", id.chomp)
  rescue => exception
    return
  end
  @jpost_info[:id] = id
  @agent = Mechanize.new
  @agent.user_agent_alias = 'Windows Mozilla'
  page = ''
  f = false
  100.times do |rev|
    if @agent.get(jpost_rev(id, rev)).search('title')[0].to_s.include?('jPOSTrepo')
      if f
        break
      else
        next
      end
    end
    page = @agent.get(jpost_rev(id, rev))
    f = true
  end

  begin
    s = page.search('Project').to_s
  rescue => exception
    return
  end
  return if s.empty?
  @jpost_info[:pxid] = s[s.index('PXD'), 9] if s.index('PXD')
  @jpost_info[:createdDate] = s[s.index('createdDate') + 13, 10]
  @jpost_info[:keywords] = page.search('Keywords').to_s.gsub('<Keywords>', '').gsub('</Keywords>', '')
  if @jpost_info[:keywords].include?(';')
    @jpost_info[:keywords] = @jpost_info[:keywords].split(';').map{ _1.strip }
  elsif @jpost_info[:keywords].include?(',')
    @jpost_info[:keywords] = @jpost_info[:keywords].split(',').map{ _1.strip }
  else
    @jpost_info[:keywords] = @jpost_info[:keywords].split().map{ _1.strip }
  end
  s = page.search('Contact')
  @jpost_info[:pi] = s.search('PrincipalInvestigator').to_s.gsub('<PrincipalInvestigator>', '').gsub('</PrincipalInvestigator>', '')
  if @jpost_info[:pi].nil?.!
    @jpost_info[:pi] = @jpost_info[:pi].gsub(/[^\w]*(Dr|MD|PhD|Prof)[^\w]*/, '')
  end
  @jpost_info[:pi] = '' if @jpost_info[:pi].upcase == @jpost_info[:pi].downcase
  @jpost_info[:pi] += '[AU]' if @jpost_info[:pi] != ''
  @jpost_info[:sm] = s.search('Name').to_s.gsub('<Name>', '').gsub('</Name>', '')
  if @jpost_info[:sm].nil?.!
    @jpost_info[:sm] = @jpost_info[:sm].gsub(/[^\w]*(Dr|MD|PhD|Prof)[^\w]*/, '')
  end
  @jpost_info[:sm] = '' if @jpost_info[:sm].upcase == @jpost_info[:sm].downcase  
  @jpost_info[:sm] += '[AU]' if @jpost_info[:sm] != ''
end

 get '/' do
  erb :index
end

def google_scholar(jpst)
  @google_scholar = { url: nil, anchor: [] }
  return if jpst.nil?
  url = "https://scholar.google.com/scholar?hl=ja&q=" + jpst
  url << "+OR+" << @pxid if !@pxid.nil?
  @google_scholar[:url] = url
  
  anchor_pdf = []
  anchor_pdf2 = []
  anchor_pmc = []
  anchor_full = []
  anchor_else = []
  begin
    page = @agent.get(url)    
  rescue => exception
    return
  end
  page.search('a').each do |anchor|
    next if anchor[:href].include?('javascript') || anchor[:href].include?('google') || anchor[:href][0] == '/' || anchor[:href].include?('https://scholar')
    if anchor[:href][-3, 3].upcase == 'PDF'
      anchor_pdf << anchor[:href]
    elsif anchor[:href].upcase.include?('PDF')
      anchor_pdf2 << anchor[:href]
    elsif anchor[:href].include?('https://www.ncbi.nlm.nih.gov/pmc/')
      anchor_pmc << anchor[:href]
    elsif anchor[:href].upcase.include?('FULL')
      anchor_pdf2 << anchor[:href]
    else
      anchor_else << anchor[:href]
    end
  end
  @google_scholar[:anchor] = anchor_pdf + anchor_pdf2 + anchor_pmc + anchor_full + anchor_else
end

def pubmed_search()
  return if @jpost_info[:createdDate].nil?
  sdate = Date.parse(@jpost_info[:createdDate][0, 8] + '01')
  
  @pubmed_id[:maxdate] = sdate.next_month(13).strftime("%Y/%m/%d")
  @pubmed_id[:mindate] = sdate.prev_month.strftime("%Y/%m/%d")
  @ids = Hash.new(0)

  options = {
    'maxdate' => @pubmed_id[:maxdate],
    'mindate' => @pubmed_id[:mindate],
    'retmax' => 100
  }

  if @pi != ''
    Bio::PubMed.esearch(@pi, options).each do |x|
      @ids[x] += 1
    end
    sleep 1
  end
  
  if @sm != '' && @pi != @sm
    Bio::PubMed.esearch(@sm, options).each do |x|
      @ids[x] += 2
    end
    sleep 1
  end
  @pubmed_id[:size] = @ids.size

  @ids.each do |k, v|
    @ids[k] = keywords_count(k, v)
    sleep 1
  end
  
  @ids.sort_by{ -_2.size }.each do |k, v|
    @ids.delete(k) if v.size == 1 && v != ['pi+sm']
  end  
end

def keywords_count(id, v)
  bibinfo = Bio::PubMed.efetch(id)
  medlines = bibinfo.map{ Bio::MEDLINE.new(_1) }
  s = ''
  a = []
  if v == 1
    a << 'pi'
  elsif v == 2
    a << 'sm'
  elsif v == 3
    a << 'pi+sm'
  end
  medlines.each do |x|
    s = x.ab.upcase  # abstract
  end
  @keywords.each do |x|
    if s.include?(x.upcase)
      a << x
    end
  end
  a
end

post '/jpost_search' do
  @jpost_info = {}
  get_jpost(params[:inputedid])
  @id = @jpost_info[:id]
  @pxid = @jpost_info[:pxid]
  @pi = @jpost_info[:pi]
  @sm = @jpost_info[:sm]
  @keywords = @jpost_info[:keywords]
  @google_scholar = {}
  google_scholar(@id)
  @gurl = @google_scholar[:url]
  @ganchors = @google_scholar[:anchor]
  @pubmed_id = {}
  if @gurl
    pubmed_search()
    @mindate = @pubmed_id[:mindate]
    @maxdate = @pubmed_id[:maxdate]
    @pubmedidsize = @pubmed_id[:size]
    if @pubmedidsize && @pubmedidsize < 100
      @pubmedids = @ids
    end  
  end

  erb :index
end
