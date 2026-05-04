import axios from "axios";

const OPEN_LIBRARY_BASE = "https://openlibrary.org";

export const getReviewsByTitle = async (req, res) => {
  const { title } = req.params;

  if (!title) {
    return res.status(400).json({ message: "Book title is required" });
  }

  try {
    // Search for the book by title
    const searchUrl = `${OPEN_LIBRARY_BASE}/search.json?title=${encodeURIComponent(title)}&limit=1`;
    const { data: searchData } = await axios.get(searchUrl);

    if (!searchData.docs || searchData.docs.length === 0) {
      return res.status(404).json({ message: "Book not found in Open Library" });
    }

    const doc = searchData.docs[0];

    // Build enriched response with available data
    const enriched = {
      title: doc.title || title,
      author: doc.author_name?.[0] || "Unknown",
      firstPublishYear: doc.first_publish_year || null,
      pageCount: doc.number_of_pages_median || null,
      subjects: doc.subject?.slice(0, 5) || [],
      ratingsAverage: doc.ratings_average
        ? parseFloat(doc.ratings_average.toFixed(1))
        : null,
      ratingsCount: doc.ratings_count || 0,
      openLibraryKey: doc.key || null,
    };

    res.status(200).json(enriched);
  } catch (error) {
    console.error("Error fetching from Open Library:", error.message);
    res.status(500).json({ message: "Error fetching book data from Open Library" });
  }
};
