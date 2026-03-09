///|
/// Shared typed page-graph artifacts produced by the builder's pass 2.
///
/// This type is intentionally shared across modules (builder, site-index, RSS)
/// so downstream emitters consume structural data rather than reparsing strings.
pub(all) struct GraphPage {
  slug : String
  title : String
  url : String
  description : String?
  date : String?
  outgoing : Array[@wikilink.ResolvedWikilink]
}
