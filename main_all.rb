require 'mechanize'
require 'bio'
require 'date'

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
  if @keywords.is_a?(Array)
    @keywords.each do |x|
      if s.include?(x.upcase)
        a << x
      end
    end
  elsif @keywords.is_a?(String)
    if s.include?(@keywords.upcase)
      a << @keywords
    end
  end
  a
end

def google_scholar(jpst)
  @write_data << '**google scholar**'
  url = "https://scholar.google.com/scholar?hl=ja&q=" + jpst
  url << "+OR+" << @pxid if @pxid != ""
  @write_data << url
  @write_data << ""
  
  anchor_pdf = []
  anchor_pdf2 = []
  anchor_pmc = []
  anchor_full = []
  anchor_else = []
  agent = Mechanize.new
  agent.user_agent_alias = 'Windows Mozilla'
  page = agent.get(url)
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
  @write_data << anchor_pdf + anchor_pdf2 + anchor_pmc + anchor_full + anchor_else
  @write_data << ""
end

def jpost_rev(id, rev)
  "https://repository.jpostdb.org/xml/" + id + ".#{rev}.xml"
end

def get_jpost(id)
  @write_data << '**jpost********************'
  @write_data << id
  puts id
  
  agent = Mechanize.new
  agent.user_agent_alias = 'Windows Mozilla'
  page = ''
  f = false
  100.times do |rev|
    if agent.get(jpost_rev(id, rev)).search('title')[0].to_s.include?('jPOSTrepo')
      if f
        break
      else
        next
      end
    end
    page = agent.get(jpost_rev(id, rev))
    f = true
  end

  @write_data << "title:#{page.search('Project').search('Title').to_s.gsub('<Title>', '').gsub('</Title>', '')}"
  s = page.search('Project').to_s
  @pxid = s.index('PXD').nil? ? '' : s[s.index('PXD'), 9]
  @createdDate = s[s.index('createdDate') + 13, 10]
  @keywords = page.search('Keywords').to_s.gsub('<Keywords>', '').gsub('</Keywords>', '')
  if @keywords.include?(';')
    @keywords = @keywords.split(';').map{ _1.strip }
  elsif @keywords.include?(',')
    @keywords = @keywords.split(',').map{ _1.strip }
  else
    @keywords = @keywords.strip
  end
  s = page.search('Contact')
  @pi = s.search('PrincipalInvestigator').to_s.gsub('<PrincipalInvestigator>', '').gsub('</PrincipalInvestigator>', '') + '[AU]'
  @sm = s.search('Name').to_s.gsub('<Name>', '').gsub('</Name>', '') + '[AU]'

  @write_data << "#{@pxid} #{@createDate} pi:#{@pi} sm:#{@sm}"
  @write_data << "keywords:#{@keywords}"
  @write_data << ""
end

def main(id)
  get_jpost id

  google_scholar(id)

  sdate = Date.parse(@createdDate[0, 8] + '01')
  
  ids = Hash.new(0)
  
  options = {
    'maxdate' => sdate.next_month(13).strftime("%Y/%m/%d"),
    'mindate' => sdate.prev_month.strftime("%Y/%m/%d"),
    'retmax' => 100
  }
  Bio::PubMed.esearch(@pi, options).each do |x|
    ids[x] += 1
  end
  sleep 1
  
  if @pi != @sm
    Bio::PubMed.esearch(@sm, options).each do |x|
      ids[x] += 2
    end
    sleep 1
  end

  @write_data << "**PubMed**"
  @write_data << "#{sdate.prev_month} - #{sdate.next_month(13)}"
  @write_data << "#{ids.keys}"
  @write_data << "#{@keywords}"
  @write_data << ""
  
  ids.each do |k, v|
    ids[k] = keywords_count(k, v)
    sleep 1
  end
  
  ids.sort_by{ -_2.size }.each do |k, v|
    next if v.size == 1 && v != ['pi+sm']
    @write_data << "http://www.ncbi.nlm.nih.gov/pubmed/#{k}"
    @write_data << "#{v}"
  end
  @write_data << ""
end

def read
  save_data = File.open("result.txt", "w")
  File.open("jpostid.txt").each do |text|
    @write_data = []
    main(text.chomp)
    save_data.puts @write_data
  end
  save_data.close
end

read()