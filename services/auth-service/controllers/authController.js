import axios from "axios";

const DUMMY_BASE = "https://dummyjson.com";

export const login = async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ message: "Username and password are required" });
  }

  try {
    // Authenticate against dummyjson
    const { data: authData } = await axios.post(`${DUMMY_BASE}/auth/login`, {
      username,
      password,
    });

    // Fetch full user profile
    const { data: userData } = await axios.get(
      `${DUMMY_BASE}/users/${authData.id}`
    );

    res.status(200).json({
      ...userData,
      token: authData.token,
    });
  } catch (error) {
    const status = error.response?.status || 500;
    const message = error.response?.data?.message || "Authentication failed";
    res.status(status).json({ message });
  }
};

export const getProfile = async (req, res) => {
  const { id } = req.params;

  try {
    const { data } = await axios.get(`${DUMMY_BASE}/users/${id}`);
    res.status(200).json(data);
  } catch (error) {
    const status = error.response?.status || 500;
    const message = error.response?.data?.message || "User not found";
    res.status(status).json({ message });
  }
};
