-- Pandoc lua-filter · suprime los bookmarks automáticos en headings.
--
-- Por defecto, pandoc genera un identifier para cada header (slug del
-- texto). Al convertir a .docx ese identifier se materializa como
-- <w:bookmarkStart>/<w:bookmarkEnd>, y Google Docs los muestra como
-- "Marcadores" visibles al lado de cada título. Como el documento de
-- acompañamiento no usa links internos, los IDs son ruido y dan trabajo
-- manual. Vaciamos identifier y attributes de cada Header para que
-- pandoc no emita los bookmarks.
function Header(el)
  el.identifier = ""
  el.attributes = {}
  return el
end
