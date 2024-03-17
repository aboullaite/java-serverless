package me.aboullaite.chatbot;

import dev.langchain4j.chain.ConversationalRetrievalChain;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ChatbotController {

  private record Prompt(String question) {}
  @Autowired
  private ChatbotService chatbotService;

  @PostMapping("/chat")
  public String chat(@RequestBody Prompt prompt) {
    ConversationalRetrievalChain rag = chatbotService.BuildRag();
    return rag.execute(prompt.question());

  }

}
